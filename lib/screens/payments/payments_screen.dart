import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/models/payment.dart';
import '../../core/models/student.dart';
import '../../core/services/auth_session_service.dart';
import '../../core/services/messaging_service.dart';
import '../../core/services/payment_service.dart';
import '../../core/services/student_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/pro_ui_kit.dart';
import '../messages/chat_screen.dart';

/// Flagship Tuition & Fee Management Screen:
/// - Parents: View active monthly due, copy CBE/Telebirr accounts, upload real receipt screenshots, track status.
/// - Admins: Issue invoices, inspect actual uploaded receipt images, approve/reject with reason, message overdue parents.
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  String _selectedFilter = 'all';

  bool get _isSuperAdmin {
    final user = SupabaseService.instance.currentUser;
    return AuthSessionService.instance.isSuperAdmin ||
        user?.email?.toLowerCase() == 'admin@kheyrukum.com';
  }

  Future<void> _handleRefresh() async {
    await PaymentService.instance.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);

    // Regular admins (not superadmin, not parent) cannot access payment data or fee registration
    if (AuthSessionService.instance.currentRole == 'admin' && !_isSuperAdmin) {
      return Scaffold(
        backgroundColor: p.canvas,
        appBar: AppBar(
          backgroundColor: p.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: p.ink),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Halaqah Fees & Tuition'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: ProEmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Access Restricted to Super Administrators',
              message:
                  'As an Administrator, you have full access to circles, students, attendance, and circulars. Financial records and tuition registrations are restricted exclusively to the Super Administrator.',
              accentColor: p.gold,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: AppBar(
        backgroundColor: p.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: p.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Halaqah Fees & Tuition'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: p.border),
        ),
        actions: [
          if (_isSuperAdmin) ...[
            TextButton.icon(
              onPressed: () => _showIssueInvoiceDialog(context),
              icon: Icon(Icons.add_circle_outline_rounded,
                  size: 17, color: p.primary),
              label: Text(
                'Issue Fee',
                style: TextStyle(
                  color: p.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.notifications_active_outlined,
                  size: 20, color: p.gold),
              tooltip: 'Send Tuition Reminder',
              onPressed: () {
                PaymentService.instance
                    .sendMonthlyTuitionReminder('Current Month');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Monthly tuition reminders broadcasted to parents.',
                    ),
                  ),
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

          if (!_isSuperAdmin) {
            final user = SupabaseService.instance.currentUser;
            final parentPayments = PaymentService.instance.getPaymentsForParent(
              user?.id ?? AuthSessionService.instance.userId,
              parentEmail:
                  user?.email ?? AuthSessionService.instance.userEmail,
            );
            return _buildParentView(context, parentPayments, p);
          }

          return _buildAdminView(context, payments, p);
        },
      ),
    );
  }

  // ===========================================================================
  // PARENT VIEW
  // ===========================================================================
  Widget _buildParentView(
      BuildContext context, List<MonthlyPayment> payments, AppPalette p) {
    MonthlyPayment? activePayment;
    MonthlyPayment? rejectedPayment;

    for (final pay in payments) {
      if (pay.isRejected && rejectedPayment == null) {
        rejectedPayment = pay;
      }
      if ((pay.isPending || pay.isSubmitted || pay.isRejected) &&
          activePayment == null) {
        activePayment = pay;
      }
    }

    if (activePayment == null && payments.isNotEmpty) {
      activePayment = payments.first;
    }

    return RefreshIndicator(
      color: p.primary,
      onRefresh: _handleRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          if (rejectedPayment != null &&
              rejectedPayment.rejectionReason != null) ...[
            ProCard(
              accentStripeColor: p.danger,
              borderColor: p.danger.withOpacity(0.45),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline_rounded, color: p.danger, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Verification Rejected',
                          style: TextStyle(
                            color: p.danger,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Reason: "${rejectedPayment.rejectionReason}"',
                          style: TextStyle(
                            color: p.ink,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () =>
                              _showUploadReceiptDialog(context, rejectedPayment!),
                          icon: const Icon(Icons.upload_file_rounded, size: 16),
                          label: const Text('Re-upload Valid Receipt'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: p.danger,
                            foregroundColor: Colors.white,
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

          if (activePayment != null)
            ProHeroCard(
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
                            const Text(
                              'MONTHLY TUITION',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                                color: AppColors.goldWarm,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              activePayment.month,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Student: ${activePayment.studentName}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.78),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusBadge(activePayment.status, p, onHero: true),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '\$${activePayment.amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '/ Monthly Fee',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white.withOpacity(0.75),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (activePayment.isApproved)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF4ADE80), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Verified & approved by ${activePayment.reviewedBy ?? "Administration"}.',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (activePayment.isSubmitted)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.hourglass_top_rounded,
                              color: AppColors.goldWarm, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Receipt uploaded. Administration is verifying your payment.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _showUploadReceiptDialog(context, activePayment!),
                        icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                        label: const Text('Upload Payment Receipt Screenshot'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.goldWarm,
                          foregroundColor: const Color(0xFF102322),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),
                ],
              ),
            )
          else
            const ProEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No Tuition Due At This Time',
              message:
                  'When center administration issues monthly tuition fees for your student, your invoices will appear here.',
            ),

          const SizedBox(height: 20),

          // Bank & Digital Channels
          ProCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance_rounded,
                        size: 20, color: p.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Direct Payment Channels',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: p.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildCopyableAccountRow(
                  context: context,
                  p: p,
                  label: 'Commercial Bank of Ethiopia (CBE)',
                  accountNumber: '1000123456789',
                ),
                const SizedBox(height: 10),
                _buildCopyableAccountRow(
                  context: context,
                  p: p,
                  label: 'Telebirr Mobile Account',
                  accountNumber: '+251 91 123 4567',
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          if (payments.isNotEmpty) ...[
            ProSectionHeader(title: 'Payment History (${payments.length})'),
            const SizedBox(height: 12),
            ...payments.map((pay) => _buildPaymentItemCard(pay, p)),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // ADMIN VIEW
  // ===========================================================================
  Widget _buildAdminView(
      BuildContext context, List<MonthlyPayment> payments, AppPalette p) {
    final pendingReview = payments.where((pay) => pay.isSubmitted).toList();
    final overdueList = payments.where((pay) => pay.isOverdue).toList();
    final approvedList = payments.where((pay) => pay.isApproved).toList();

    final filteredList = payments.where((pay) {
      if (_selectedFilter == 'all') return true;
      return pay.status == _selectedFilter;
    }).toList();

    return RefreshIndicator(
      color: p.primary,
      onRefresh: _handleRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Row(
            children: [
              _buildAdminStatCard(
                p: p,
                title: 'To Review',
                value: '${pendingReview.length}',
                icon: Icons.pending_actions_rounded,
                color: p.info,
              ),
              const SizedBox(width: 10),
              _buildAdminStatCard(
                p: p,
                title: 'Overdue',
                value: '${overdueList.length}',
                icon: Icons.warning_amber_rounded,
                color: p.danger,
              ),
              const SizedBox(width: 10),
              _buildAdminStatCard(
                p: p,
                title: 'Approved',
                value: '${approvedList.length}',
                icon: Icons.check_circle_rounded,
                color: p.success,
              ),
            ],
          ),
          const SizedBox(height: 22),

          if (pendingReview.isNotEmpty) ...[
            ProSectionHeader(
              title: 'Receipts Awaiting Review (${pendingReview.length})',
              trailing: ProStatusPill(label: 'Action Required', color: p.info),
            ),
            const SizedBox(height: 12),
            ...pendingReview
                .map((pay) => _buildPendingReviewCard(pay, p)),
            const SizedBox(height: 18),
          ],

          if (overdueList.isNotEmpty) ...[
            ProSectionHeader(
              title: 'Overdue Accounts (${overdueList.length})',
              trailing: ProStatusPill(label: 'Past Due', color: p.danger),
            ),
            const SizedBox(height: 12),
            ...overdueList.map((pay) => _buildOverdueAccountCard(pay, p)),
            const SizedBox(height: 18),
          ],

          ProSectionHeader(
            title: 'Tuition Records (${payments.length})',
            trailing: TextButton(
              onPressed: () => _showIssueInvoiceDialog(context),
              child: const Text('+ Issue Tuition'),
            ),
          ),
          const SizedBox(height: 10),

          if (payments.isEmpty)
            ProEmptyState(
              icon: Icons.payments_outlined,
              title: 'No Tuition Fees Issued Yet',
              message:
                  'Issue monthly tuition fees to enrolled students so parents can make payments and upload receipts.',
              actionLabel: 'Issue First Tuition Fee',
              onAction: () => _showIssueInvoiceDialog(context),
            )
          else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all', p),
                  _buildFilterChip('Submitted', 'submitted', p),
                  _buildFilterChip('Approved', 'approved', p),
                  _buildFilterChip('Rejected', 'rejected', p),
                  _buildFilterChip('Pending', 'pending', p),
                  _buildFilterChip('Overdue', 'overdue', p),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ...filteredList.map((pay) => _buildPaymentItemCard(pay, p)),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingReviewCard(MonthlyPayment payment, AppPalette p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ProCard(
        borderColor: p.info.withOpacity(0.45),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${payment.studentName} (${payment.month})',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: p.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Parent: ${payment.parentName}',
                        style: TextStyle(fontSize: 12, color: p.inkSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  '\$${payment.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                    color: p.success,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _showReceiptInspectorDialog(context, payment),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.surfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.image_search_rounded, size: 20, color: p.info),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Receipt Screenshot Attached • Tap to Inspect',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: p.info,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 18, color: p.info),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(context, payment),
                    icon: Icon(Icons.close_rounded, size: 16, color: p.danger),
                    label: Text(
                      'Reject',
                      style: TextStyle(
                        color: p.danger,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: p.danger.withOpacity(0.6)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await PaymentService.instance
                          .approvePayment(paymentId: payment.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Payment approved for ${payment.studentName}.',
                            ),
                            backgroundColor: p.success,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: p.success,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverdueAccountCard(MonthlyPayment payment, AppPalette p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ProCard(
        accentStripeColor: p.danger,
        borderColor: p.danger.withOpacity(0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${payment.studentName} • ${payment.month}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: p.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Parent: ${payment.parentName} (${payment.parentEmail})',
                        style: TextStyle(fontSize: 12, color: p.inkSecondary),
                      ),
                    ],
                  ),
                ),
                ProStatusPill(label: 'OVERDUE', color: p.danger),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      PaymentService.instance.sendOverdueAlertToAdmin(payment);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Overdue alert dispatched for ${payment.parentName}.',
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.notifications_active_rounded,
                        size: 15, color: p.gold),
                    label: Text(
                      'Send Alert',
                      style: TextStyle(fontSize: 12, color: p.gold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (payment.parentId.isEmpty) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${payment.studentName} has no linked parent account yet.',
                              ),
                            ),
                          );
                        }
                        return;
                      }
                      final convo = await MessagingService.instance
                          .startDirectChatWithParent(
                        parentId: payment.parentId,
                        parentName: payment.parentName,
                      );
                      if (mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              conversationId: convo.id,
                              conversationTitle: convo.title,
                              targetRole: 'parent',
                            ),
                          ),
                        );
                      }
                    },
                    icon: Icon(Icons.chat_bubble_outline_rounded,
                        size: 15, color: p.primary),
                    label: Text(
                      'Message Parent',
                      style: TextStyle(fontSize: 12, color: p.primary),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentItemCard(MonthlyPayment payment, AppPalette p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ProCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${payment.month} — ${payment.studentName}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: p.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(payment.status, p),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Amount: \$${payment.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: p.inkSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (payment.hasReceipt)
                  InkWell(
                    onTap: () => _showReceiptInspectorDialog(context, payment),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_rounded,
                              size: 14, color: p.primary),
                          const SizedBox(width: 4),
                          Text(
                            'View Receipt',
                            style: TextStyle(
                              fontSize: 12,
                              color: p.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            if (payment.isRejected && payment.rejectionReason != null) ...[
              const SizedBox(height: 6),
              Text(
                'Rejection Reason: "${payment.rejectionReason}"',
                style: TextStyle(
                  fontSize: 11.5,
                  color: p.danger,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCopyableAccountRow({
    required BuildContext context,
    required AppPalette p,
    required String label,
    required String accountNumber,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: p.surfaceSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11.5, color: p.inkSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  accountNumber,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                    letterSpacing: 0.4,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: accountNumber));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label copied to clipboard.')),
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: p.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy_rounded, size: 14, color: p.primary),
                  const SizedBox(width: 5),
                  Text(
                    'Copy',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: p.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminStatCard({
    required AppPalette p,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: ProCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: p.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: p.inkSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, AppPalette p) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? p.primary : p.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? p.primary : p.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? p.onPrimary : p.inkSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, AppPalette p, {bool onHero = false}) {
    Color color = p.gold;
    String label = status.toUpperCase();

    if (status == 'approved') {
      color = onHero ? const Color(0xFF4ADE80) : p.success;
    } else if (status == 'submitted') {
      color = onHero ? AppColors.goldWarm : p.info;
      label = 'IN REVIEW';
    } else if (status == 'rejected' || status == 'overdue') {
      color = onHero ? const Color(0xFFFCA5A5) : p.danger;
    }

    return ProStatusPill(label: label, color: color, showDot: true);
  }

  // ===========================================================================
  // DIALOGS
  // ===========================================================================
  void _showIssueInvoiceDialog(BuildContext context) {
    final students = StudentService.instance.allStudents;
    if (students.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No Students Enrolled'),
          content: const Text(
            'Please add at least one student in the Students tab before issuing tuition fees.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Understood'),
            ),
          ],
        ),
      );
      return;
    }

    Student selectedStudent = students.first;
    DateTime feeStartDate = DateTime.now();
    final monthCtrl = TextEditingController(text: 'October 2026');
    final amountCtrl = TextEditingController(text: '50');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Issue Monthly Tuition Fee'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<Student>(
                  value: selectedStudent,
                  isExpanded: true,
                  items: students
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(
                              '${s.fullName} (${s.parentName})',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ))
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => selectedStudent = val!),
                  decoration: const InputDecoration(labelText: 'Select Student'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: monthCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tuition Month (e.g. October 2026)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Fee Amount (\$)'),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: feeStartDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setDialogState(() => feeStartDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black26),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Fee Start Date *',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.black54),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              feeStartDate.toLocal().toString().substring(0, 10),
                              style: const TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const Icon(Icons.calendar_today_rounded,
                            size: 18, color: Colors.black54),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text) ?? 50.0;
                try {
                  await PaymentService.instance.createPaymentInvoice(
                    studentId: selectedStudent.id,
                    studentName: selectedStudent.fullName,
                    parentId: selectedStudent.parentId ?? '',
                    parentName: selectedStudent.parentName,
                    parentEmail: selectedStudent.parentPhone,
                    month: monthCtrl.text.trim(),
                    amount: amt,
                    dueDate: DateTime.now().add(const Duration(days: 10)),
                    feeStartDate: feeStartDate,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Tuition issued for ${selectedStudent.fullName}.',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(SupabaseService.cleanErrorMessage(e)),
                        backgroundColor: AppColors.of(context).danger,
                      ),
                    );
                  }
                }
              },
              child: const Text('Issue Tuition'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUploadReceiptDialog(BuildContext context, MonthlyPayment payment) {
    final p = AppColors.of(context);
    String selectedMethod = 'Commercial Bank of Ethiopia (CBE)';
    final noteCtrl =
        TextEditingController(text: 'Payment completed via mobile banking.');
    XFile? selectedReceipt;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Upload Payment Receipt'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Student: ${payment.studentName} (${payment.month})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Amount Due: \$${payment.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: p.primary,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: selectedMethod,
                  items: const [
                    DropdownMenuItem(
                      value: 'Commercial Bank of Ethiopia (CBE)',
                      child: Text('CBE Mobile Banking'),
                    ),
                    DropdownMenuItem(
                      value: 'Telebirr',
                      child: Text('Telebirr Mobile'),
                    ),
                    DropdownMenuItem(
                      value: 'Cash Deposit',
                      child: Text('Cash Slip'),
                    ),
                  ],
                  onChanged: isUploading
                      ? null
                      : (val) => setDialogState(() => selectedMethod = val!),
                  decoration:
                      const InputDecoration(labelText: 'Payment Channel'),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: isUploading
                      ? null
                      : () async {
                          final picked = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 85,
                          );
                          if (picked != null) {
                            setDialogState(() => selectedReceipt = picked);
                          }
                        },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: p.primarySoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.primary.withOpacity(0.35)),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          selectedReceipt != null
                              ? Icons.check_circle_outline_rounded
                              : Icons.add_photo_alternate_rounded,
                          size: 32,
                          color: p.primary,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          selectedReceipt != null
                              ? 'Selected: ${selectedReceipt!.name}'
                              : 'Tap to Pick Receipt Screenshot',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: p.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selectedReceipt != null
                              ? 'Tap to change image'
                              : 'Choose payment slip or screenshot from gallery',
                          style: TextStyle(fontSize: 11, color: p.inkMuted),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  enabled: !isUploading,
                  decoration: const InputDecoration(
                    labelText: 'Transaction Reference / Notes',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (isUploading || selectedReceipt == null)
                  ? null
                  : () async {
                      setDialogState(() => isUploading = true);
                      try {
                        final bytes = await selectedReceipt!.readAsBytes();
                        final uploadedUrl =
                            await PaymentService.instance.uploadReceipt(
                          paymentId: payment.id,
                          fileName: selectedReceipt!.name,
                          bytes: bytes,
                        );
                        if (uploadedUrl == null || uploadedUrl.isEmpty) {
                          throw Exception(
                            'Failed to upload receipt image to cloud storage.',
                          );
                        }
                        await PaymentService.instance.submitPaymentReceipt(
                          paymentId: payment.id,
                          receiptUrl: uploadedUrl,
                          customNote:
                              '$selectedMethod — ${noteCtrl.text.trim()}',
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Receipt submitted successfully. Admin will verify.',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isUploading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text(SupabaseService.cleanErrorMessage(e)),
                              backgroundColor: p.danger,
                            ),
                          );
                        }
                      }
                    },
              child: isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit Receipt'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiptInspectorDialog(
      BuildContext context, MonthlyPayment payment) {
    final p = AppColors.of(context);
    final hasValidUrl = payment.receiptUrl != null &&
        payment.receiptUrl!.trim().startsWith('http');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Receipt Inspector'),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasValidUrl) ...[
                GestureDetector(
                  onTap: () => _openFullScreenReceipt(payment.receiptUrl!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      children: [
                        Container(
                          constraints: const BoxConstraints(maxHeight: 240),
                          width: double.infinity,
                          color: p.surfaceSubtle,
                          child: Image.network(
                            payment.receiptUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return SizedBox(
                                height: 150,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: p.primary,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Icon(Icons.broken_image_rounded,
                                      color: p.inkMuted, size: 32),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Could not load receipt image',
                                    style: TextStyle(
                                        fontSize: 12, color: p.inkMuted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.zoom_in_rounded,
                                    size: 13, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Tap to Zoom',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: p.surfaceSubtle,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.border),
                ),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_rounded,
                        size: 28, color: p.primary),
                    const SizedBox(height: 6),
                    Text(
                      'PAYMENT SUMMARY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: p.ink,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const Divider(height: 18),
                    _buildReceiptRow(p, 'Beneficiary', 'Kheyrukum Center'),
                    _buildReceiptRow(p, 'Payer Name', payment.parentName),
                    _buildReceiptRow(p, 'Student', payment.studentName),
                    _buildReceiptRow(p, 'Month', payment.month),
                    _buildReceiptRow(
                        p, 'Amount', '\$${payment.amount.toStringAsFixed(2)}'),
                    _buildReceiptRow(p, 'Status', payment.status.toUpperCase()),
                  ],
                ),
              ),
              if (payment.notes != null && payment.notes!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Parent Note: "${payment.notes}"',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    color: p.inkSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (_isSuperAdmin && payment.isSubmitted) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showRejectDialog(context, payment);
              },
              child: Text(
                'Reject with Reason',
                style: TextStyle(color: p.danger),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                await PaymentService.instance
                    .approvePayment(paymentId: payment.id);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Payment approved for ${payment.studentName}.'),
                      backgroundColor: p.success,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: p.success,
                foregroundColor: Colors.white,
              ),
              child: const Text('Approve Payment'),
            ),
          ] else
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
        ],
      ),
    );
  }

  void _openFullScreenReceipt(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Receipt Image',
                style: TextStyle(color: Colors.white)),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.6,
              maxScale: 4.0,
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildReceiptRow(AppPalette p, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: p.inkSecondary)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: p.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, MonthlyPayment payment) {
    final p = AppColors.of(context);
    final reasonCtrl = TextEditingController(
      text:
          'The uploaded screenshot is blurry and the transaction reference number cannot be read. Please re-upload.',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Payment Receipt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Specify why ${payment.parentName}\'s receipt is rejected. This reason will be shown to the parent.',
              style: const TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason *',
                hintText:
                    'e.g. Blurry screenshot, incorrect amount, missing reference...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonCtrl.text.trim().isNotEmpty) {
                await PaymentService.instance.rejectPayment(
                  paymentId: payment.id,
                  reason: reasonCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Payment rejected and reason sent to ${payment.parentName}.',
                      ),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: p.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );
  }
}
