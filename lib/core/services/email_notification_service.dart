import '../firebase/firebase_service.dart';
import '../../data/models/contribution.dart';
import '../../data/models/loan.dart';
import '../../data/models/repayment.dart';
import '../../data/models/returns_info.dart';
import '../../data/models/monthly_report.dart';

class EmailNotificationService {
  static Future<void> sendMonthlyReportEmail(
    String userId,
    List<Contribution> contributions,
    List<Loan> loans,
    List<Repayment> repayments,
    List<ReturnsInfo> returns,
    List<MonthlyReport> monthlyReports,
  ) async {
    try {
      final userDoc = await FirebaseService.firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        throw Exception('User not found');
      }
      
      final userData = userDoc.data()!;
      final userEmail = userData['email'] ?? '';
      
      if (userEmail.isEmpty) {
        throw Exception('User email not found');
      }
      
      final subject = 'LendWUs Monthly Report - ${DateTime.now().month}/${DateTime.now().year}';
      final body = _generateMonthlyReportBody(
        userData['name'] ?? 'User',
        contributions,
        loans,
        repayments,
        returns,
        monthlyReports,
      );
      
      await _sendEmail(userEmail, subject, body);
      
      print('Monthly report email sent to $userEmail');
    } catch (e) {
      print('Error sending monthly report email: $e');
      rethrow;
    }
  }

  static Future<void> sendPaymentConfirmationEmail(
    String userId,
    Contribution contribution,
    String memberName,
  ) async {
    try {
      final userDoc = await FirebaseService.firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        throw Exception('User not found');
      }
      
      final userData = userDoc.data()!;
      final userEmail = userData['email'] ?? '';
      
      if (userEmail.isEmpty) {
        throw Exception('User email not found');
      }
      
      final subject = 'Contribution Confirmed - ₱${contribution.amount}';
      final body = _generatePaymentConfirmationBody(
        userData['name'] ?? 'User',
        contribution,
        memberName,
      );
      
      await _sendEmail(userEmail, subject, body);
      
      print('Payment confirmation email sent to $userEmail');
    } catch (e) {
      print('Error sending payment confirmation email: $e');
      rethrow;
    }
  }

  static Future<void> sendLoanApprovalEmail(
    String userId,
    Loan loan,
    String memberName,
  ) async {
    try {
      final userDoc = await FirebaseService.firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        throw Exception('User not found');
      }
      
      final userData = userDoc.data()!;
      final userEmail = userData['email'] ?? '';
      
      if (userEmail.isEmpty) {
        throw Exception('User email not found');
      }
      
      final subject = 'Loan Approved - ₱${loan.principal}';
      final body = _generateLoanApprovalBody(
        userData['name'] ?? 'User',
        loan,
        memberName,
      );
      
      await _sendEmail(userEmail, subject, body);
      
      print('Loan approval email sent to $userEmail');
    } catch (e) {
      print('Error sending loan approval email: $e');
      rethrow;
    }
  }

  static Future<void> sendRepaymentConfirmationEmail(
    String userId,
    Repayment repayment,
    String memberName,
    String loanId,
  ) async {
    try {
      final userDoc = await FirebaseService.firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        throw Exception('User not found');
      }
      
      final userData = userDoc.data()!;
      final userEmail = userData['email'] ?? '';
      
      if (userEmail.isEmpty) {
        throw Exception('User email not found');
      }
      
      final subject = 'Repayment Confirmed - ₱${repayment.amountPaid}';
      final body = _generateRepaymentConfirmationBody(
        userData['name'] ?? 'User',
        repayment,
        memberName,
        loanId,
      );
      
      await _sendEmail(userEmail, subject, body);
      
      print('Repayment confirmation email sent to $userEmail');
    } catch (e) {
      print('Error sending repayment confirmation email: $e');
      rethrow;
    }
  }

  static Future<void> sendWelcomeEmail(String userId, String password) async {
    try {
      final userDoc = await FirebaseService.firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        throw Exception('User not found');
      }
      
      final userData = userDoc.data()!;
      final userEmail = userData['email'] ?? '';
      
      if (userEmail.isEmpty) {
        throw Exception('User email not found');
      }
      
      const subject = 'Welcome to LendWUs - Your Account Details';
      final body = _generateWelcomeBody(
        userData['name'] ?? 'User',
        userEmail,
        password,
      );
      
      await _sendEmail(userEmail, subject, body);
      
      print('Welcome email sent to $userEmail');
    } catch (e) {
      print('Error sending welcome email: $e');
      rethrow;
    }
  }

  static Future<void> sendMonthlyReportBatch(
    List<Map<String, dynamic>> userDataList,
    List<Contribution> contributions,
    List<Loan> loans,
    List<Repayment> repayments,
    List<ReturnsInfo> returns,
    List<MonthlyReport> monthlyReports,
  ) async {
    for (final userData in userDataList) {
      final userEmail = userData['email'] as String;
      final userName = userData['name'] as String;
      
      try {
        final subject = 'LendWUs Monthly Report - ${DateTime.now().month}/${DateTime.now().year}';
        final body = _generateMonthlyReportBody(
          userName,
          contributions,
          loans,
          repayments,
          returns,
          monthlyReports,
        );
        
        await _sendEmail(userEmail, subject, body);
        
        print('Monthly report batch email sent to $userEmail');
        
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        print('Error sending batch email to $userEmail: $e');
      }
    }
  }

  /// This function logs to Firestore's `email_logs` collection.
  /// A Firebase Cloud Function (e.g., `functions/processEmailLogs`) must read
  /// documents from this collection and actually dispatch the emails via
  /// nodemailer, SendGrid, or similar transport.
  ///
  /// Deployment guide for the Cloud Function:
  /// ```bash
  /// firebase init functions
  /// cd functions && npm install nodemailer
  /// # Write a onDocumentCreated handler for email_logs
  /// ```
  static Future<void> _sendEmail(String to, String subject, String body) async {
    await FirebaseService.firestore.collection('email_logs').add({
      'to': to,
      'subject': subject,
      'body': body,
      'sent_at': DateTime.now().toIso8601String(),
      'status': 'sent',
    });
    
    print('Email queued for $to: $subject');
  }

  static String _generateMonthlyReportBody(
    String userName,
    List<Contribution> contributions,
    List<Loan> loans,
    List<Repayment> repayments,
    List<ReturnsInfo> returns,
    List<MonthlyReport> monthlyReports,
  ) {
    final currentMonth = DateTime.now().month;
    final currentYear = DateTime.now().year;
    
    final userContributions = contributions.where((c) => c.month == currentMonth && c.year == currentYear).toList();
    final userLoans = loans.where((l) => l.memberId == 'current_user_id').toList();
    final userRepayments = repayments.where((r) => loans.any((l) => l.id == r.loanId && l.memberId == 'current_user_id')).toList();
    final userReturns = returns.toList();
    
    final totalContributions = userContributions.fold(0.0, (sum, c) => sum + c.amount);
    final totalLoans = userLoans.fold(0.0, (sum, l) => sum + l.principal);
    final totalRepayments = userRepayments.fold(0.0, (sum, r) => sum + r.amountPaid);
    final totalReturns = userReturns.fold(0.0, (sum, r) => sum + r.perHeadShare);
    
    final monthlyReport = monthlyReports.firstWhere(
      (r) => r.year == currentYear && r.month == currentMonth,
      orElse: () => MonthlyReport(
        month: currentMonth,
        year: currentYear,
        totalContribution: totalContributions,
        loansIssued: totalLoans,
        interestGained: 0,
        endingBalance: totalReturns,
      ),
    );
    final netChange = monthlyReport.endingBalance - monthlyReport.totalContribution;
    
    return '''
Hi $userName,

Here's your LendWUs Monthly Report for ${getMonthName(currentMonth)} $currentYear:

=== SUMMARY ===
Total Contributions: ₱$totalContributions
Total Loans Issued: ₱$totalLoans
Total Repayments Made: ₱$totalRepayments
Total Returns Received: ₱$totalReturns

=== DETAILED BREAKDOWN ===
Contributions:
${_formatContributionsList(userContributions)}

Loans:
${_formatLoansList(userLoans)}

Repayments:
${_formatRepaymentsList(userRepayments)}

Returns:
${_formatReturnsList(userReturns)}

=== ACCOUNT SUMMARY ===
Net Balance: ₱$netChange
Total Active Loans: ${userLoans.length}
Payment Due This Month: ₱${_calculateUpcomingPayments(userRepayments)}

=== ACTION ITEMS ===
${_getActionItems(userContributions, userRepayments)}

=== NEXT STEPS ===
- Review your upcoming payments
- Check if you need to make additional contributions
- Monitor your loan progress
- Plan for next month's budget

Best regards,
LendWUs Team
''';
  }

  static String _generatePaymentConfirmationBody(
    String userName,
    Contribution contribution,
    String memberName,
  ) {
    return '''
Hi $userName,

Your contribution has been successfully recorded!

=== PAYMENT DETAILS ===
Member: $memberName
Amount: ₱${contribution.amount}
Date: ${contribution.date.day} ${getMonthName(contribution.date.month)} ${contribution.date.year}
Month: ${contribution.month}/${contribution.year}
Notes: ${contribution.notes ?? 'N/A'}

=== NEXT STEPS ===
- Thank you for your contribution to the group fund
- Your contribution helps support other members' financial goals
- You can make additional contributions anytime

Best regards,
LendWUs Team
''';
  }

  static   String _generateLoanApprovalBody(
    String userName,
    Loan loan,
    String memberName,
  ) {
    final termMonths = loan.dueDate.difference(loan.issuedDate).inDays ~/ 30;
    return '''
Hi $userName,

Your loan has been approved!

=== LOAN DETAILS ===
Loan Amount: ₱${loan.principal}
Interest Rate: ${(loan.interestRate * 100).toStringAsFixed(1)}%
Term: $termMonths months
Start Date: ${loan.issuedDate.day} ${getMonthName(loan.issuedDate.month)} ${loan.issuedDate.year}
Due Date: ${loan.dueDate.day} ${getMonthName(loan.dueDate.month)} ${loan.dueDate.year}

=== REPAYMENT SCHEDULE ===
Monthly Payment: ₱${(loan.principal / termMonths).toStringAsFixed(2)}
Total Interest: ₱${(loan.principal * loan.interestRate * termMonths / 12).toStringAsFixed(2)}

=== NEXT STEPS ===
- Review your loan agreement
- Schedule your first payment
- Contact support if you have questions

Best regards,
LendWUs Team
''';
  }

  static String _generateRepaymentConfirmationBody(
    String userName,
    Repayment repayment,
    String memberName,
    String loanId,
  ) {
    return '''
Hi $userName,

Your loan repayment has been received!

=== PAYMENT DETAILS ===
Repayment Amount: ₱${repayment.amountPaid}
Payment Date: ${repayment.date.day} ${getMonthName(repayment.date.month)} ${repayment.date.year}

=== LOAN INFORMATION ===
Loan ID: $loanId
Approved By: $memberName

=== ACCOUNT IMPACT ===
Remaining Balance: ₱${_calculateRemainingBalance(loanId, repayment.amountPaid)}
Next Payment Due: ${_calculateNextPaymentDate(loanId)}

=== THANK YOU ===
Your timely payments help maintain the lending circle for all members.

Best regards,
LendWUs Team
''';
  }

  static String _generateWelcomeBody(
    String userName,
    String userEmail,
    String password,
  ) {
    return '''
Welcome to LendWUs, $userName!

=== ACCOUNT SETUP ===
Email: $userEmail
Temporary Password: $password

=== QUICK START ===
1. Log in with your email and password
2. Complete your profile information
3. Join a group using code: LENDWUS
4. Start making contributions
5. Apply for loans when ready

=== FEATURES ===
- Track your contributions and savings
- Apply for loans with competitive interest rates
- Monitor loan repayments and balances
- Receive automated return calculations
- Connect with other group members
- Access detailed analytics and reports

=== NEED HELP? ===
Visit our help center or contact support at support@lendwus.app

=== NEXT STEPS ===
Your financial journey starts here. Welcome to the community!

Best regards,
LendWus Team
''';
  }

  static String _formatContributionsList(List<Contribution> contributions) {
    if (contributions.isEmpty) return 'No contributions recorded this month.';
    
    final buffer = StringBuffer();
    for (final contribution in contributions) {
      buffer.writeln('• ₱${contribution.amount} on ${contribution.date.day} ${getMonthName(contribution.date.month)}');
    }
    return buffer.toString();
  }

  static   String _formatLoansList(List<Loan> loans) {
    if (loans.isEmpty) return 'No loans issued this month.';
    
    final buffer = StringBuffer();
    for (final loan in loans) {
      buffer.writeln('• ₱${loan.principal} issued on ${loan.issuedDate.day} ${getMonthName(loan.issuedDate.month)}');
    }
    return buffer.toString();
  }

  static String _formatRepaymentsList(List<Repayment> repayments) {
    if (repayments.isEmpty) return 'No repayments made this month.';
    
    final buffer = StringBuffer();
    for (final repayment in repayments) {
      buffer.writeln('• ₱${repayment.amountPaid} paid on ${repayment.date.day} ${getMonthName(repayment.date.month)}');
    }
    return buffer.toString();
  }

  static String _formatReturnsList(List<ReturnsInfo> returns) {
    if (returns.isEmpty) return 'No returns available this year.';
    
    final buffer = StringBuffer();
    for (final returnInfo in returns) {
      buffer.writeln('• ₱${returnInfo.perHeadShare} per head');
    }
    return buffer.toString();
  }

  static String _getActionItems(List<Contribution> contributions, List<Repayment> repayments) {
    final currentMonth = DateTime.now().month;
    
    final buffer = StringBuffer();
    
    if (contributions.isEmpty) {
      buffer.writeln('• Make your contribution for $currentMonth');
    }
    
    if (repayments.isEmpty) {
      buffer.writeln('• Pay your loan installment for this month');
    } else {
      final lastRepayment = repayments.last;
      if (lastRepayment.date.month == currentMonth) {
        buffer.writeln('• ✓ Contribution and repayment completed for this month');
      }
    }
    
    if (buffer.isEmpty) {
      return '• No action items - You\'re all caught up!';
    }
    
    return buffer.toString();
  }

  static String _calculateUpcomingPayments(List<Repayment> repayments) {
    final currentMonth = DateTime.now().month;
    final currentYear = DateTime.now().year;
    
    final upcomingRepayments = repayments.where((r) =>
        r.date.month == currentMonth && r.date.year == currentYear
    ).toList();
    
    return upcomingRepayments.fold(0.0, (sum, r) => sum + r.amountPaid).toStringAsFixed(2);
  }

  /// Placeholder: requires a Firestore query on the repayments subcollection
  /// to compute the actual remaining balance. Returns "N/A" until implemented.
  static String _calculateRemainingBalance(String loanId, double paymentAmount) {
    return 'N/A';
  }

  /// Placeholder: requires a Firestore query on the loans doc's dueDate field
  /// to return the next scheduled payment date. Returns "N/A" until implemented.
  static String _calculateNextPaymentDate(String loanId) {
    return 'N/A';
  }

  static String getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}
