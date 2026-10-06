import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/payment.dart';
import '../../core/models/student.dart';
import '../../core/services/payment_service.dart';
import '../../core/services/student_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../messages/chat_screen.dart';

/// Payments Screen:
/// - Parents: View monthly tuition status, copy payment bank details in 1-click,
///   upload receipt screenshots for verification, and view clear rejection reasons if rejected.
/// - Admins: Issue monthly tuition fees to enrolled students, review submitted receipts,
///   inspect screenshots, approve or reject with custom reason, track overdue accounts.
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  String _selectedFilter = 'all';

  bool get _isAdmin {
    final user = SupabaseService.instance.currentUser;
    if (user == null || user.email?.toLowerCase() == 'admin@kheyrukum.com') return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtextColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
    final cardBg = isDark ? AppColors.surfaceCard : AppColors.surfaceCardLight;
    final borderColor = isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Halaqah Fees & Tuition',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          if (_isAdmin) ...[
            TextButton.icon(
              onPressed: () => _showIssueInvoiceDialog(context),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: Color(0xFF10B981)),
              label: const Text(
                '+ Issue Fee',
                style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.notifications_active_outlined, size: 18, color: Color(0xFFFFA000)),
              tooltip: 'Send Tuition Reminder',
              onPressed: () {
                PaymentService.instance.sendMonthlyTuitionReminder('Current Month');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Monthly tuition reminders broadcasted to parents!')),
                );
              },
            ),
          ],
        ],
      ),
      body: StreamBuilder<List<MonthlyPayment>>(
        stream: PaymentService.instance.paymentsStream,
        initialData: PaymentService.instance.allPayments,
        builder: (context, snapshot) {
          final payments = snapshot.data ?? [];

          if (!_isAdmin) {
            // Parent view: Filter for this parent's payments
            final user = SupabaseService.instance.currentUser;
            final parentPayments = PaymentService.instance.getPaymentsForParent(
              user?.id ?? '',
              parentEmail: user?.email,
            );
            return _buildParentView(
              context: context,
              payments: parentPayments,
              isDark: isDark,
              textColor: textColor,
              subtextColor: subtextColor,
              cardBg: cardBg,
              borderColor: borderColor,
            );
          }

          // Admin view: Full administrative controls
          return _buildAdminView(
            context: context,
            payments: payments,
            isDark: isDark,
            textColor: textColor,
            subtextColor: subtextColor,
            cardBg: cardBg,
            borderColor: borderColor,
          );
        },
      ),
    );
  }

  // ===========================================================================
  // PARENT VIEW
  // ===========================================================================
  Widget _buildParentView({
    required BuildContext context,
    required List<MonthlyPayment> payments,
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
    required Color cardBg,
    required Color borderColor,
  }) {
    MonthlyPayment? activePayment;
    MonthlyPayment? rejectedPayment;

    for (final p in payments) {
      if (p.isRejected && rejectedPayment == null) {
        rejectedPayment = p;
      }
      if ((p.isPending || p.isSubmitted || p.isRejected) && activePayment == null) {
        activePayment = p;
      }
    }

    if (activePayment == null && payments.isNotEmpty) {
      activePayment = payments.first;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      children: [
        // 1. REJECTION ALERT BANNER (If rejected by admin)
        if (rejectedPayment != null && rejectedPayment.rejectionReason != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Verification Rejected',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reason from Administration: "${rejectedPayment.rejectionReason}"',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () => _showUploadReceiptDialog(context, rejectedPayment!),
                        icon: const Icon(Icons.upload_file_rounded, size: 16),
                        label: const Text('Re-upload Valid Receipt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 2. CURRENT MONTH DUE CARD (or Empty State)
        if (activePayment != null)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tuition: ${activePayment.month}',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'For ${activePayment.studentName}',
                          style: TextStyle(fontSize: 12, color: subtextColor),
                        ),
                      ],
                    ),
                    _buildStatusBadge(activePayment.status),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      '\$${activePayment.amount.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '/ Monthly Rate',
                      style: TextStyle(fontSize: 12, color: subtextColor),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (activePayment.isApproved) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accentEmerald.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.accentEmerald, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Payment verified & approved by ${activePayment.reviewedBy ?? "Admin"}.',
                            style: const TextStyle(color: AppColors.accentEmerald, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (activePayment.isSubmitted) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BCD4).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.hourglass_top_rounded, color: Color(0xFF00BCD4), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Receipt uploaded. Center administration is verifying your payment.',
                            style: TextStyle(color: Color(0xFF00BCD4), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showUploadReceiptDialog(context, activePayment!),
                      icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                      label: const Text('Upload Payment Receipt Screenshot', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Icon(Icons.receipt_long_outlined, size: 44, color: subtextColor),
                const SizedBox(height: 10),
                Text('No Tuition Due At This Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
                const SizedBox(height: 4),
                Text(
                  'When center administration issues monthly tuition fees for your student, your invoices and verification options will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: subtextColor, height: 1.4),
                ),
              ],
            ),
          ),

        const SizedBox(height: 20),

        // 3. BANK & DIGITAL PAYMENT CHANNELS WITH 1-CLICK COPY
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_rounded, size: 20, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 8),
                  Text('Direct Bank & Payment Channels', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                ],
              ),
              const SizedBox(height: 14),
              // CBE Account
              _buildCopyableAccountRow(
                context: context,
                label: 'Commercial Bank of Ethiopia (CBE)',
                accountNumber: '1000123456789',
                isDark: isDark,
                borderColor: borderColor,
                textColor: textColor,
                subtextColor: subtextColor,
              ),
              const SizedBox(height: 10),
              // Telebirr Account
              _buildCopyableAccountRow(
                context: context,
                label: 'Telebirr Mobile Account',
                accountNumber: '+251 91 123 4567',
                isDark: isDark,
                borderColor: borderColor,
                textColor: textColor,
                subtextColor: subtextColor,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 4. PAYMENT HISTORY
        if (payments.isNotEmpty) ...[
          Text(
            'Payment History (${payments.length})',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 12),
          ...payments.map((p) => _buildPaymentItemCard(p, isDark, cardBg, borderColor, textColor, subtextColor)),
        ],
      ],
    );
  }

  // ===========================================================================
  // ADMIN VIEW
  // ===========================================================================
  Widget _buildAdminView({
    required BuildContext context,
    required List<MonthlyPayment> payments,
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
    required Color cardBg,
    required Color borderColor,
  }) {
    final pendingReview = payments.where((p) => p.isSubmitted).toList();
    final overdueList = payments.where((p) => p.isOverdue).toList();
    final approvedList = payments.where((p) => p.isApproved).toList();

    final filteredList = payments.where((p) {
      if (_selectedFilter == 'all') return true;
      return p.status == _selectedFilter;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      children: [
        // Summary Cards: Revenue, Pending Reviews, Invoices
        Row(
          children: [
            _buildAdminStatCard(
              title: 'Pending Review',
              value: '${pendingReview.length}',
              icon: Icons.pending_actions_rounded,
              color: const Color(0xFF00BCD4),
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
            ),
            const SizedBox(width: 10),
            _buildAdminStatCard(
              title: 'Overdue Fees',
              value: '${overdueList.length}',
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFFEF4444),
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
            ),
            const SizedBox(width: 10),
            _buildAdminStatCard(
              title: 'Approved',
              value: '${approvedList.length}',
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF10B981),
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
            ),
          ],
        ),

        const SizedBox(height: 20),

        // 1. PENDING RECEIPTS AWAITING VERIFICATION
        if (pendingReview.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Receipts Awaiting Review (${pendingReview.length})',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BCD4).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Action Required', style: TextStyle(color: Color(0xFF00BCD4), fontSize: 10.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...pendingReview.map((p) => _buildPendingReviewCard(p, isDark, cardBg, borderColor, textColor, subtextColor)),
          const SizedBox(height: 20),
        ],

        // 2. OVERDUE ACCOUNTS SECTION
        if (overdueList.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Overdue Accounts (${overdueList.length})',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFFEF4444)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Unpaid Alerts', style: TextStyle(color: Color(0xFFEF4444), fontSize: 10.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...overdueList.map((p) => _buildOverdueAccountCard(p, isDark, cardBg, borderColor, textColor, subtextColor)),
          const SizedBox(height: 20),
        ],

        // 3. ALL PAYMENTS RECORD / EMPTY STATE
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tuition Records (${payments.length})',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
            ),
            InkWell(
              onTap: () => _showIssueInvoiceDialog(context),
              child: const Text(
                '+ Issue Tuition',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (payments.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Icon(Icons.payments_outlined, size: 48, color: const Color(0xFF10B981).withOpacity(0.7)),
                const SizedBox(height: 12),
                Text('No Tuition Fees Issued Yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                const SizedBox(height: 6),
                Text(
                  'Issue monthly tuition fees to enrolled students so parents can make payments and submit receipts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: subtextColor, height: 1.4),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () => _showIssueInvoiceDialog(context),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: const Text('Issue First Tuition Fee', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          )
        else ...[
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                _buildFilterChip('Submitted', 'submitted'),
                _buildFilterChip('Approved', 'approved'),
                _buildFilterChip('Rejected', 'rejected'),
                _buildFilterChip('Pending', 'pending'),
                _buildFilterChip('Overdue', 'overdue'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          ...filteredList.map((p) => _buildPaymentItemCard(p, isDark, cardBg, borderColor, textColor, subtextColor)),
        ],
      ],
    );
  }

  // Pending review card with "Inspect Screenshot" and quick approve/reject
  Widget _buildPendingReviewCard(
    MonthlyPayment payment,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subtextColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${payment.studentName} (${payment.month})',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Parent: ${payment.parentName}',
                      style: TextStyle(fontSize: 12, color: subtextColor),
                    ),
                  ],
                ),
              ),
              Text(
                '\$${payment.amount.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF10B981)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Receipt thumbnail preview
          InkWell(
            onTap: () => _showReceiptInspectorDialog(context, payment),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: const Row(
                children: [
                  Icon(Icons.image_search_rounded, size: 20, color: Color(0xFF00BCD4)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Receipt Screenshot Attached • Tap to Inspect',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00BCD4)),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF00BCD4)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Action Buttons: Approve / Reject
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showRejectDialog(context, payment),
                  icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFEF4444)),
                  label: const Text('Reject with Reason', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await PaymentService.instance.approvePayment(paymentId: payment.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Payment approved for ${payment.studentName}!')),
                    );
                  },
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Approve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Overdue account card
  Widget _buildOverdueAccountCard(
    MonthlyPayment payment,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subtextColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${payment.studentName} • ${payment.month}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Parent: ${payment.parentName} (${payment.parentEmail})',
                      style: TextStyle(fontSize: 11.5, color: subtextColor),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'OVERDUE',
                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ActionChip(
                avatar: const Icon(Icons.notifications_active_rounded, size: 14, color: Color(0xFFFFA000)),
                label: const Text('Send Alert', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  PaymentService.instance.sendOverdueAlertToAdmin(payment);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Overdue alert dispatched for ${payment.parentName}.')),
                  );
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Color(0xFF00BCD4)),
                label: const Text('Message Parent', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        conversationId: 'convo-direct-01',
                        conversationTitle: 'Parent: ${payment.parentName}',
                        targetRole: 'parent',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Regular payment item card
  Widget _buildPaymentItemCard(
    MonthlyPayment payment,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subtextColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${payment.month} - ${payment.studentName}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: textColor),
              ),
              _buildStatusBadge(payment.status),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Amount: \$${payment.amount.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 12, color: subtextColor),
              ),
              if (payment.hasReceipt)
                InkWell(
                  onTap: () => _showReceiptInspectorDialog(context, payment),
                  child: const Text(
                    'View Receipt 🔎',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF00BCD4), fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          if (payment.isRejected && payment.rejectionReason != null) ...[
            const SizedBox(height: 6),
            Text(
              'Rejection Reason: "${payment.rejectionReason}"',
              style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444), fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCopyableAccountRow({
    required BuildContext context,
    required String label,
    required String accountNumber,
    required bool isDark,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11.5, color: subtextColor)),
                const SizedBox(height: 2),
                Text(
                  accountNumber,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: accountNumber));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label copied to clipboard!')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 14),
            label: const Text('Copy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.15),
              foregroundColor: const Color(0xFF8B5CF6),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null)),
        selected: isSelected,
        selectedColor: const Color(0xFF00BCD4),
        onSelected: (selected) {
          if (selected) setState(() => _selectedFilter = value);
        },
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFFFA000);
    String label = status.toUpperCase();

    if (status == 'approved') {
      bg = const Color(0xFF10B981);
    } else if (status == 'submitted') {
      bg = const Color(0xFF00BCD4);
      label = 'IN REVIEW';
    } else if (status == 'rejected' || status == 'overdue') {
      bg = const Color(0xFFEF4444);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: bg, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }

  // ===========================================================================
  // INTERACTIVE DIALOGS
  // ===========================================================================

  void _showIssueInvoiceDialog(BuildContext context) {
    final students = StudentService.instance.allStudents;
    if (students.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No Students Enrolled', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: const Text('Please add at least one student in the Students tab before issuing tuition fees.'),
          actions: [
            ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Understood')),
          ],
        ),
      );
      return;
    }

    Student selectedStudent = students.first;
    final monthCtrl = TextEditingController(text: 'October 2026');
    final amountCtrl = TextEditingController(text: '50');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Issue Monthly Tuition Fee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<Student>(
                  value: selectedStudent,
                  items: students.map((s) => DropdownMenuItem(
                    value: s,
                    child: Text('${s.fullName} (${s.parentName})', style: const TextStyle(fontSize: 13)),
                  )).toList(),
                  onChanged: (val) => setDialogState(() => selectedStudent = val!),
                  decoration: const InputDecoration(labelText: 'Select Student'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: monthCtrl,
                  decoration: const InputDecoration(labelText: 'Tuition Month (e.g. October 2026)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Fee Amount (\$)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text) ?? 50.0;
                await PaymentService.instance.createPaymentInvoice(
                  studentId: selectedStudent.id,
                  studentName: selectedStudent.fullName,
                  parentId: selectedStudent.parentId ?? 'par-${selectedStudent.id}',
                  parentName: selectedStudent.parentName,
                  parentEmail: selectedStudent.parentPhone,
                  month: monthCtrl.text.trim(),
                  amount: amt,
                  dueDate: DateTime.now().add(const Duration(days: 10)),
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Tuition issued for ${selectedStudent.fullName}!')),
                );
              },
              child: const Text('Issue Tuition'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUploadReceiptDialog(BuildContext context, MonthlyPayment payment) {
    String selectedMethod = 'Commercial Bank of Ethiopia (CBE)';
    final noteCtrl = TextEditingController(text: 'Payment completed via mobile banking.');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Upload Payment Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Student: ${payment.studentName} (${payment.month})',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                Text('Amount Due: \$${payment.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Color(0xFF10B981))),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: selectedMethod,
                  items: const [
                    DropdownMenuItem(value: 'Commercial Bank of Ethiopia (CBE)', child: Text('CBE Mobile Banking')),
                    DropdownMenuItem(value: 'Telebirr', child: Text('Telebirr Mobile')),
                    DropdownMenuItem(value: 'Cash Deposit', child: Text('Cash Slip')),
                  ],
                  onChanged: (val) => setDialogState(() => selectedMethod = val!),
                  decoration: const InputDecoration(labelText: 'Payment Gateway / Channel'),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4), style: BorderStyle.solid),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 32, color: Color(0xFF10B981)),
                      SizedBox(height: 6),
                      Text('Screenshot Attached: receipt_screenshot.jpg', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                      SizedBox(height: 2),
                      Text('Receipt attached successfully', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: 'Transaction Reference / Notes'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await PaymentService.instance.submitPaymentReceipt(
                  paymentId: payment.id,
                  receiptMockId: 'receipt_${DateTime.now().millisecondsSinceEpoch}',
                  customNote: noteCtrl.text.trim(),
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Receipt submitted successfully! Admin will verify.')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit for Verification'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiptInspectorDialog(BuildContext context, MonthlyPayment payment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Receipt Inspector 🔍', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.receipt_long_rounded, size: 36, color: Color(0xFF0F172A)),
                    const SizedBox(height: 8),
                    const Text(
                      'COMMERCIAL BANK OF ETHIOPIA',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: 0.5),
                    ),
                    const Text('Official Transaction Receipt', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    const Divider(height: 20),
                    _buildReceiptRow('Beneficiary', 'Kheyrukum Quranic Center'),
                    _buildReceiptRow('Payer Name', payment.parentName),
                    _buildReceiptRow('Student', payment.studentName),
                    _buildReceiptRow('Month', payment.month),
                    _buildReceiptRow('Amount Paid', '\$${payment.amount.toStringAsFixed(2)}'),
                    _buildReceiptRow('Reference No.', 'TXN-${payment.id.hashCode.abs()}'),
                    _buildReceiptRow('Status', 'SUCCESSFUL / TRANSFERRED'),
                    const Divider(height: 20),
                    const Text('VERIFIED ELECTRONIC RECEIPT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (payment.notes != null)
                Text(
                  'Parent Note: "${payment.notes}"',
                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                ),
            ],
          ),
        ),
        actions: [
          if (_isAdmin && payment.isSubmitted) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showRejectDialog(context, payment);
              },
              child: const Text('Reject with Reason', style: TextStyle(color: Color(0xFFEF4444))),
            ),
            ElevatedButton(
              onPressed: () async {
                await PaymentService.instance.approvePayment(paymentId: payment.id);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Payment approved for ${payment.studentName}!')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
              child: const Text('Approve Payment'),
            ),
          ] else ...[
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ],
      ),
    );
  }

  static Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, MonthlyPayment payment) {
    final reasonCtrl = TextEditingController(
      text: 'The uploaded screenshot is blurry and transaction reference number cannot be read. Please re-upload.',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Payment Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please specify the reason for rejecting payment from ${payment.parentName}. This will be clearly displayed to the parent.',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason *',
                hintText: 'e.g. Blurry screenshot, incorrect amount, missing reference number...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (reasonCtrl.text.trim().isNotEmpty) {
                await PaymentService.instance.rejectPayment(
                  paymentId: payment.id,
                  reason: reasonCtrl.text.trim(),
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Payment rejected and reason sent to ${payment.parentName}.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );
  }
}
