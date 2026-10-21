enum ReviewState {
  pendingReview,
  approved,
  rejected,
  alreadyKnown,
  needsMoreEvidence,
  conflict;

  static ReviewState fromString(String value) {
    switch (value.toLowerCase().replaceAll('-', '_')) {
      case 'approved':
        return ReviewState.approved;
      case 'rejected':
        return ReviewState.rejected;
      case 'already_known':
        return ReviewState.alreadyKnown;
      case 'needs_more_evidence':
        return ReviewState.needsMoreEvidence;
      case 'conflict':
        return ReviewState.conflict;
      case 'pending_review':
      default:
        return ReviewState.pendingReview;
    }
  }

  String toValue() {
    switch (this) {
      case ReviewState.pendingReview:
        return 'pending_review';
      case ReviewState.approved:
        return 'approved';
      case ReviewState.rejected:
        return 'rejected';
      case ReviewState.alreadyKnown:
        return 'already_known';
      case ReviewState.needsMoreEvidence:
        return 'needs_more_evidence';
      case ReviewState.conflict:
        return 'conflict';
    }
  }

  String get displayName {
    switch (this) {
      case ReviewState.pendingReview:
        return 'Pending Review';
      case ReviewState.approved:
        return 'Approved';
      case ReviewState.rejected:
        return 'Rejected';
      case ReviewState.alreadyKnown:
        return 'Already In Inventory';
      case ReviewState.needsMoreEvidence:
        return 'Needs More Evidence';
      case ReviewState.conflict:
        return 'Identity Conflict';
    }
  }
}
