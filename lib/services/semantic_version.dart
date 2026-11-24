/// A small semantic-version implementation used for update checks.
///
/// The app compares the version reported by `package_info_plus` with the
/// version in a GitHub release tag. Release tags frequently carry a `v` prefix
/// and may contain pre-release/build identifiers, so comparing the raw strings
/// (or their numeric fragments) is not enough.
///
/// Build metadata (`+42`) never affects precedence. Pre-release identifiers
/// (`1.4.0-beta.2`) are lower than the corresponding release (`1.4.0`), as
/// defined by SemVer 2.0.0.
class SemanticVersion implements Comparable<SemanticVersion> {
  SemanticVersion._(this.core, this.preRelease);

  /// Numeric major/minor/patch components. Missing components are treated as 0.
  final List<int> core;

  /// Dot-separated pre-release identifiers. Empty for a normal release.
  final List<String> preRelease;

  /// Parses `1`, `1.3`, `v1.3.0`, `1.3.0+12`, `1.3.0-beta.1`.
  ///
  /// Returns `null` when [raw] does not contain a usable version. A release tag
  /// such as `release-1.3.0` is intentionally rejected instead of guessing
  /// which part of the string is the version.
  static SemanticVersion? tryParse(String? raw) {
    if (raw == null) return null;

    var value = raw.trim();
    if (value.isEmpty) return null;

    // GitHub tags are commonly written as v1.3.0.
    value = value.replaceFirst(RegExp(r'^[vV](?=\d)'), '');

    // Build metadata has no effect on precedence.
    final plusIndex = value.indexOf('+');
    if (plusIndex >= 0) {
      value = value.substring(0, plusIndex);
    }

    // Pre-release suffix, e.g. -beta.2.
    final dashIndex = value.indexOf('-');
    var corePart = value;
    var preReleasePart = '';
    if (dashIndex >= 0) {
      corePart = value.substring(0, dashIndex);
      preReleasePart = value.substring(dashIndex + 1);
    }

    final coreParts = corePart.split('.');
    if (coreParts.isEmpty || coreParts.length > 4) return null;

    final core = <int>[];
    for (final part in coreParts) {
      if (part.isEmpty || !RegExp(r'^\d+$').hasMatch(part)) return null;
      core.add(int.parse(part));
    }

    while (core.length < 3) {
      core.add(0);
    }

    final preRelease = <String>[];
    if (preReleasePart.isNotEmpty) {
      for (final identifier in preReleasePart.split('.')) {
        if (identifier.isEmpty) return null;
        if (!RegExp(r'^[0-9A-Za-z-]+$').hasMatch(identifier)) return null;
        preRelease.add(identifier);
      }
    }

    return SemanticVersion._(
      List.unmodifiable(core),
      List.unmodifiable(preRelease),
    );
  }

  bool get isPreRelease => preRelease.isNotEmpty;

  @override
  int compareTo(SemanticVersion other) {
    final length = core.length > other.core.length
        ? core.length
        : other.core.length;

    for (var i = 0; i < length; i++) {
      final left = i < core.length ? core[i] : 0;
      final right = i < other.core.length ? other.core[i] : 0;
      if (left != right) return left.compareTo(right);
    }

    // A release has higher precedence than any pre-release of the same version.
    if (preRelease.isEmpty && other.preRelease.isEmpty) return 0;
    if (preRelease.isEmpty) return 1;
    if (other.preRelease.isEmpty) return -1;

    final preLength = preRelease.length > other.preRelease.length
        ? preRelease.length
        : other.preRelease.length;

    for (var i = 0; i < preLength; i++) {
      if (i >= preRelease.length) return -1;
      if (i >= other.preRelease.length) return 1;

      final left = preRelease[i];
      final right = other.preRelease[i];
      final leftIsNumber = RegExp(r'^\d+$').hasMatch(left);
      final rightIsNumber = RegExp(r'^\d+$').hasMatch(right);

      if (leftIsNumber && rightIsNumber) {
        final result = int.parse(left).compareTo(int.parse(right));
        if (result != 0) return result;
      } else if (leftIsNumber) {
        // Numeric identifiers have lower precedence than alphanumeric ones.
        return -1;
      } else if (rightIsNumber) {
        return 1;
      } else {
        final result = left.compareTo(right);
        if (result != 0) return result;
      }
    }

    return 0;
  }

  bool isNewerThan(SemanticVersion other) => compareTo(other) > 0;
  bool isSameAs(SemanticVersion other) => compareTo(other) == 0;

  @override
  bool operator ==(Object other) =>
      other is SemanticVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hashAll([...core, ...preRelease]);

  @override
  String toString() {
    final version = core.join('.');
    return isPreRelease ? '$version-${preRelease.join('.')}' : version;
  }
}

/// Compares two version strings. Returns a negative number when [a] is older
/// than [b], zero when they have equal precedence, and a positive number when
/// [a] is newer.
///
/// Throws [FormatException] if either value is not a valid version. Callers
/// that talk to the network must treat that as a failed update check rather
/// than assuming the app is up to date.
int compareSemanticVersions(String a, String b) {
  final first = SemanticVersion.tryParse(a);
  final second = SemanticVersion.tryParse(b);

  if (first == null) {
    throw FormatException('Invalid version: $a');
  }
  if (second == null) {
    throw FormatException('Invalid version: $b');
  }

  return first.compareTo(second);
}

/// Whether [latest] is a genuinely newer published version than [current].
bool isUpdateAvailable({required String current, required String latest}) {
  return compareSemanticVersions(latest, current) > 0;
}
