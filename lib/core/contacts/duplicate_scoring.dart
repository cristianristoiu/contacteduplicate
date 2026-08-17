import 'dart:math' as math;

import 'contact_data_normalizer.dart';
import 'contact_models.dart';

class DuplicateScoringPolicy {
  final int safeThreshold;
  final int probableThreshold;
  final int manualReviewThreshold;
  final double similarNameThreshold;
  final int maxPopularKeyOwners;
  final int minimumUsefulNameLength;

  const DuplicateScoringPolicy({
    this.safeThreshold = 95,
    this.probableThreshold = 80,
    this.manualReviewThreshold = 60,
    this.similarNameThreshold = 0.78,
    this.maxPopularKeyOwners = 25,
    this.minimumUsefulNameLength = 3,
  })  : assert(safeThreshold <= 100),
        assert(probableThreshold < safeThreshold),
        assert(manualReviewThreshold < probableThreshold),
        assert(similarNameThreshold >= 0 && similarNameThreshold <= 1),
        assert(maxPopularKeyOwners >= 2),
        assert(minimumUsefulNameLength >= 2);

  DuplicateConfidenceLabel labelFor(int score) {
    if (score >= safeThreshold) return DuplicateConfidenceLabel.safe;
    if (score >= probableThreshold) return DuplicateConfidenceLabel.probable;
    if (score >= manualReviewThreshold) return DuplicateConfidenceLabel.manualReview;
    return DuplicateConfidenceLabel.ignored;
  }

  bool canAutoSelect(int score) => score >= safeThreshold;
  bool shouldSurface(int score) => score >= manualReviewThreshold;
}

class DuplicateScoreResult {
  final int score;
  final DuplicateConfidenceLabel label;
  final List<MatchEvidence> evidence;
  final bool requiresManualReview;
  final bool canAutoSelect;

  DuplicateScoreResult({
    required this.score,
    required this.label,
    required Iterable<MatchEvidence> evidence,
    required this.requiresManualReview,
    required this.canAutoSelect,
  }) : evidence = List<MatchEvidence>.unmodifiable(evidence);
}

class DuplicateScorer {
  final ContactDataNormalizer normalizer;
  final DuplicateScoringPolicy policy;

  DuplicateScorer({
    ContactDataNormalizer? normalizer,
    this.policy = const DuplicateScoringPolicy(),
  }) : normalizer = normalizer ?? ContactDataNormalizer();

  DuplicateScoreResult scorePair(ContactRecord left, ContactRecord right) {
    final evidence = <MatchEvidence>[];
    final sharedPhones = _intersection(
      left.phones.where((value) => value.isMatchable).map((value) => value.canonicalKey),
      right.phones.where((value) => value.isMatchable).map((value) => value.canonicalKey),
    );
    final sharedEmails = _intersection(
      left.emails.where((value) => value.isMatchable).map((value) => value.canonicalKey),
      right.emails.where((value) => value.isMatchable).map((value) => value.canonicalKey),
    );

    if (sharedPhones.isNotEmpty) {
      evidence.add(MatchEvidence(
        kind: MatchEvidenceKind.phoneExact,
        scoreContribution: 95,
        evidenceFingerprint: stableOpaqueId(sharedPhones, namespace: 'phone'),
        strong: true,
      ));
    }
    if (sharedEmails.isNotEmpty) {
      evidence.add(MatchEvidence(
        kind: MatchEvidenceKind.emailExact,
        scoreContribution: 95,
        evidenceFingerprint: stableOpaqueId(sharedEmails, namespace: 'email'),
        strong: true,
      ));
    }

    final leftName = left.name.hasOriginalDisplayName ? left.name.displayName : '';
    final rightName = right.name.hasOriginalDisplayName ? right.name.displayName : '';
    final exactLeftName = normalizer.exactNameKey(leftName);
    final exactRightName = normalizer.exactNameKey(rightName);
    final fuzzyLeftName = normalizer.fuzzyNameKey(leftName);
    final fuzzyRightName = normalizer.fuzzyNameKey(rightName);
    final namesUseful = _isUsefulName(fuzzyLeftName) && _isUsefulName(fuzzyRightName);

    if (namesUseful && exactLeftName == exactRightName) {
      evidence.add(MatchEvidence(
        kind: MatchEvidenceKind.nameExact,
        scoreContribution: 30,
        evidenceFingerprint: stableOpaqueId(<String>[exactLeftName], namespace: 'name'),
        strong: false,
      ));
    } else if (namesUseful && normalizer.areObviousNameInversions(leftName, rightName)) {
      evidence.add(MatchEvidence(
        kind: MatchEvidenceKind.nameInverted,
        scoreContribution: 26,
        evidenceFingerprint: stableOpaqueId(<String>[normalizer.orderInsensitiveNameKey(leftName)], namespace: 'name'),
        strong: false,
      ));
    } else if (namesUseful) {
      final similarity = nameSimilarity(leftName, rightName);
      if (similarity >= policy.similarNameThreshold) {
        evidence.add(MatchEvidence(
          kind: MatchEvidenceKind.nameSimilar,
          scoreContribution: (similarity * 25).round().clamp(15, 25).toInt(),
          evidenceFingerprint: stableOpaqueId(<String>[normalizer.orderInsensitiveNameKey(leftName), normalizer.orderInsensitiveNameKey(rightName)], namespace: 'fuzzy-name'),
          strong: false,
        ));
      }
    }

    final leftCompanies = left.organizations.map((value) => value.companyKey).where((value) => value.isNotEmpty).toSet();
    final rightCompanies = right.organizations.map((value) => value.companyKey).where((value) => value.isNotEmpty).toSet();
    final sharedCompanies = leftCompanies.intersection(rightCompanies);
    if (sharedCompanies.isNotEmpty && namesUseful) {
      evidence.add(MatchEvidence(
        kind: MatchEvidenceKind.companyExact,
        scoreContribution: 18,
        evidenceFingerprint: stableOpaqueId(sharedCompanies, namespace: 'company'),
        strong: false,
      ));
    }

    final hasNameSignal = evidence.any((item) => item.kind == MatchEvidenceKind.nameExact || item.kind == MatchEvidenceKind.nameInverted || item.kind == MatchEvidenceKind.nameSimilar);
    if (hasNameSignal && sharedPhones.isNotEmpty) {
      evidence.add(MatchEvidence(
        kind: MatchEvidenceKind.nameAndPhone,
        scoreContribution: 5,
        evidenceFingerprint: stableOpaqueId(<String>[left.nativeId, right.nativeId], namespace: 'name-phone'),
        strong: true,
      ));
    }
    if (hasNameSignal && sharedEmails.isNotEmpty) {
      evidence.add(MatchEvidence(
        kind: MatchEvidenceKind.nameAndEmail,
        scoreContribution: 5,
        evidenceFingerprint: stableOpaqueId(<String>[left.nativeId, right.nativeId], namespace: 'name-email'),
        strong: true,
      ));
    }
    if (hasNameSignal && sharedCompanies.isNotEmpty) {
      evidence.add(MatchEvidence(
        kind: MatchEvidenceKind.nameAndCompany,
        scoreContribution: 15,
        evidenceFingerprint: stableOpaqueId(<String>[left.nativeId, right.nativeId], namespace: 'name-company'),
        strong: false,
      ));
    }

    var score = _combineEvidence(evidence);
    if (_isInitialOnlyMatch(leftName, rightName) && sharedPhones.isEmpty && sharedEmails.isEmpty) {
      score = math.min(score, policy.manualReviewThreshold);
    }
    if (!left.hasStableNativeId || !right.hasStableNativeId) {
      score = math.min(score, policy.probableThreshold - 1);
    }
    score = score.clamp(0, 100).toInt();
    final label = policy.labelFor(score);
    return DuplicateScoreResult(
      score: score,
      label: label,
      evidence: evidence,
      requiresManualReview: label == DuplicateConfidenceLabel.manualReview || label == DuplicateConfidenceLabel.probable,
      canAutoSelect: policy.canAutoSelect(score) && left.hasStableNativeId && right.hasStableNativeId,
    );
  }

  double nameSimilarity(String left, String right) {
    final leftKey = normalizer.fuzzyNameKey(left);
    final rightKey = normalizer.fuzzyNameKey(right);
    if (leftKey.isEmpty || rightKey.isEmpty) return 0;
    if (leftKey == rightKey) return 1;
    if (normalizer.orderInsensitiveNameKey(left) == normalizer.orderInsensitiveNameKey(right)) return 0.98;

    final tokenScore = _tokenSimilarity(normalizer.tokenizeName(left), normalizer.tokenizeName(right));
    final editScore = _normalizedEditSimilarity(leftKey, rightKey);
    final prefixScore = _prefixSimilarity(leftKey, rightKey);
    return (tokenScore * 0.5 + editScore * 0.4 + prefixScore * 0.1).clamp(0, 1).toDouble();
  }

  int _combineEvidence(List<MatchEvidence> evidence) {
    final hasPhone = evidence.any((item) => item.kind == MatchEvidenceKind.phoneExact);
    final hasEmail = evidence.any((item) => item.kind == MatchEvidenceKind.emailExact);
    if (hasPhone && hasEmail) return 100;
    if (hasPhone || hasEmail) return 95;

    final hasExactName = evidence.any((item) => item.kind == MatchEvidenceKind.nameExact || item.kind == MatchEvidenceKind.nameInverted);
    final hasCompany = evidence.any((item) => item.kind == MatchEvidenceKind.companyExact);
    if (hasExactName && hasCompany) return 88;
    if (hasExactName) return 82;

    final hasSimilarName = evidence.any((item) => item.kind == MatchEvidenceKind.nameSimilar);
    if (hasSimilarName && hasCompany) return 76;
    if (hasSimilarName) return 65;
    return 0;
  }

  bool _isUsefulName(String value) {
    final compact = value.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return compact.length >= policy.minimumUsefulNameLength;
  }

  bool _isInitialOnlyMatch(String left, String right) {
    final leftTokens = normalizer.tokenizeName(left);
    final rightTokens = normalizer.tokenizeName(right);
    if (leftTokens.isEmpty || rightTokens.isEmpty) return false;
    return leftTokens.any((token) => token.length == 1) || rightTokens.any((token) => token.length == 1);
  }

  static Set<String> _intersection(Iterable<String> left, Iterable<String> right) {
    final leftSet = left.where((value) => value.isNotEmpty).toSet();
    return leftSet.intersection(right.where((value) => value.isNotEmpty).toSet());
  }

  static double _tokenSimilarity(List<String> left, List<String> right) {
    if (left.isEmpty || right.isEmpty) return 0;
    final leftSet = left.toSet();
    final rightSet = right.toSet();
    final common = leftSet.intersection(rightSet).length;
    final union = leftSet.union(rightSet).length;
    return union == 0 ? 0 : common / union;
  }

  static double _normalizedEditSimilarity(String left, String right) {
    final distance = _levenshtein(left, right);
    final longest = math.max(left.length, right.length);
    return longest == 0 ? 1 : 1 - distance / longest;
  }

  static double _prefixSimilarity(String left, String right) {
    final maxLength = math.min(left.length, right.length);
    if (maxLength == 0) return 0;
    var common = 0;
    while (common < maxLength && left.codeUnitAt(common) == right.codeUnitAt(common)) {
      common++;
    }
    return common / maxLength;
  }

  static int _levenshtein(String left, String right) {
    if (left == right) return 0;
    if (left.isEmpty) return right.length;
    if (right.isEmpty) return left.length;
    var previous = List<int>.generate(right.length + 1, (index) => index);
    for (var i = 0; i < left.length; i++) {
      final current = <int>[i + 1];
      for (var j = 0; j < right.length; j++) {
        final substitution = previous[j] + (left.codeUnitAt(i) == right.codeUnitAt(j) ? 0 : 1);
        final insertion = current[j] + 1;
        final deletion = previous[j + 1] + 1;
        current.add(math.min(substitution, math.min(insertion, deletion)));
      }
      previous = current;
    }
    return previous.last;
  }
}
