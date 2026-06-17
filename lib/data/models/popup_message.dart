class PopupMessage {
  final String title;
  final String message;
  final bool isDefault;
  final String category;

  const PopupMessage({
    required this.title,
    required this.message,
    this.isDefault = false,
    this.category = 'general',
  });

  factory PopupMessage.fromMap(Map<String, dynamic> map) {
    return PopupMessage(
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      category: map['category'] ?? 'general',
    );
  }

  static const List<PopupMessage> defaults = [
    // General tips
    PopupMessage(
      title: '💡 Did You Know?',
      message: 'You can request a head count change anytime through the app under Requests.',
      category: 'general', isDefault: true,
    ),
    PopupMessage(
      title: '📈 Fund Growth',
      message: 'Your contributions help the fund grow. The more members contribute, the bigger the loan pool for everyone!',
      category: 'general', isDefault: true,
    ),
    PopupMessage(
      title: '👥 Invite Family',
      message: 'The more active members we have, the faster the fund grows. Encourage family to join!',
      category: 'general', isDefault: true,
    ),
    PopupMessage(
      title: '📱 Stay Updated',
      message: 'Enable notifications to get alerts on approvals, confirmations, and fund updates.',
      category: 'general', isDefault: true,
    ),
    PopupMessage(
      title: '🔒 Quick Access',
      message: 'Enable biometric login in Settings for faster, secure sign-in without typing your password.',
      category: 'security', isDefault: true,
    ),
    PopupMessage(
      title: '🔐 Secure Your Account',
      message: 'Use a strong password and never share your login credentials with anyone.',
      category: 'security', isDefault: true,
    ),
    // Loan-specific
    PopupMessage(
      title: '💰 Loan Repayment Due',
      message: 'You have an active loan! Make sure to pay on time to keep the fund healthy.',
      category: 'loan', isDefault: true,
    ),
    PopupMessage(
      title: '📊 Track Your Loans',
      message: 'View your loan balance, payment history, and repayment schedule anytime in the Loans tab.',
      category: 'loan', isDefault: true,
    ),
    PopupMessage(
      title: '⏰ Pay Before Due Date',
      message: 'Paying your loan early saves on interest and makes funds available for other members.',
      category: 'loan', isDefault: true,
    ),
    PopupMessage(
      title: '📋 Need Help With Repayment?',
      message: 'If you\'re having trouble with repayment, talk to the admin about extending your due date.',
      category: 'loan', isDefault: true,
    ),
    // Savings & contributions
    PopupMessage(
      title: '⏰ Contribution Reminder',
      message: 'Don\'t forget to pay your monthly contribution on time to stay in good standing!',
      category: 'savings', isDefault: true,
    ),
    PopupMessage(
      title: '🎯 Double Your Savings',
      message: 'Consistent contributions every cutoff mean bigger returns at year-end.',
      category: 'savings', isDefault: true,
    ),
    PopupMessage(
      title: '📊 Monitor Your Progress',
      message: 'Check your contribution history and payment status on the dashboard to stay on track.',
      category: 'savings', isDefault: true,
    ),
  ];
}
