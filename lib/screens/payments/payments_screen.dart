import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/payment.dart';
import '../../core/models/student.dart';
import '../../core/services/auth_session_service.dart';
import '../../core/services/messaging_service.dart';
import '../../core/services/payment_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/student_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/pro_shimmer.dart';
import '../../widgets/pro_ui_kit.dart';
import '../messages/chat_screen.dart';

/// Flagship Tuition & Fee Management Screen:
/// - Parents: View active monthly due, copy configured center bank/mobile accounts, upload real receipt screenshots, track status.
/// - Admins: Issue invoices, inspect actual uploaded receipt images, approve/reject with reason, message overdue parents.
class PaymentsScreen extends StatefulWidget {
  final bool embedded;

  const PaymentsScreen({super.key, this.embedded = false});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  String _selectedFilter = 'all';

  bool get _isSuperAdmin => AuthSessionService.instance.isSuperAdmin;

  Future<void> _handleRefresh() async {
    await PaymentService.instance.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);

    // Fail-closed: only Superadmins and Parents can access payment data or fee registration
    if (!AuthSessionService.instance.canAccessPayments) {
      final restrictedView = Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: ProEmptyState(
            icon: Icons.lock_outline_rounded,
            title: loc.tuitionAndFees,
            message: loc.accessRestrictedFees,
            accentColor: p.gold,
          ),
        ),
      );
      if (widget.embedded) return restrictedView;

      return Scaffold(
        backgroundColor: p.canvas,
        appBar: AppBar(
          backgroundColor: p.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: p.ink),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(loc.tuitionAndFees),
        ),
        body: restrictedView,
      );
    }

    final body = StreamBuilder<List<MonthlyPayment>>(
      stream: PaymentService.instance.paymentsStream,
      initialData: PaymentService.instance.allPayments,
      builder: (context, snapshot) {
        final payments = snapshot.data ?? [];
        if (snapshot.connectionState == ConnectionState.waiting &&
            payments.isEmpty) {
          return const ProCardListSkeleton();
        }

        if (!_isSuperAdmin) {
          final user = SupabaseService.instance.currentUser;
          final parentPayments = PaymentService.instance.getPaymentsForParent(
            user?.id ?? AuthSessionService.instance.userId,
            parentEmail: user?.email ?? AuthSessionService.instance.userEmail,
          );
          return _buildParentView(context, parentPayments, p);
        }

        return _buildAdminView(context, payments, p);
      },
    );

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: AppBar(
        backgroundColor: p.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: p.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(loc.tuitionAndFees),
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
                loc.issueFee,
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
              tooltip: loc.sendMonthlyReminders,
              onPressed: () {
                PaymentService.instance.sendMonthlyTuitionReminder(
                  loc.formatMonthYear(DateTime.now()),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(loc.monthlyFeeReminder),
                  ),
                );
              },
            ),
          ],
        ],
      ),
      body: body,
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
        padding: EdgeInsets.fromLTRB(
          20,
          widget.embedded ? 8 : 16,
          20,
          widget.embedded ? 132 : 40,
        ),
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
                          AppLocalizations.of(context)
                              .translate('paymentVerificationRejectedTitle'),
                          style: TextStyle(
                            color: p.danger,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(context).tr('reasonLabelValue', {
                            'reason': '${rejectedPayment.rejectionReason}',
                          }),
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
                          label: Text(AppLocalizations.of(context)
                              .translate('reuploadValidReceiptAction')),
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
                            Text(
                              AppLocalizations.of(context)
                                  .translate('monthlyTuitionHeader'),
                              style: const TextStyle(
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
                              AppLocalizations.of(context)
                                  .tr('studentLineLabel', {
                                'name': activePayment.studentName,
                              }),
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
                        AppLocalizations.of(context)
                            .formatCurrency(activePayment.amount),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)
                            .translate('perMonthlyFeeSuffix'),
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
                              AppLocalizations.of(context)
                                  .tr('verifiedApprovedByLine', {
                                'name': activePayment.displayReviewerName ??
                                    AppLocalizations.of(context)
                                        .translate('centerDirectorFallback'),
                              }),
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
                      child: Row(
                        children: [
                          const Icon(Icons.hourglass_top_rounded,
                              color: AppColors.goldWarm, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context)
                                  .translate('receiptUploadedVerifyingMsg'),
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
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _showUploadReceiptDialog(context, activePayment!),
                        icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                        label: Text(AppLocalizations.of(context)
                            .translate('uploadReceiptScreenshotAction')),
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
            ProEmptyState(
              icon: Icons.receipt_long_outlined,
              title:
                  AppLocalizations.of(context).translate('noTuitionDueTitle'),
              message:
                  AppLocalizations.of(context).translate('noTuitionDueDesc'),
            ),

          const SizedBox(height: 20),

          // Bank & Digital Channels
          _buildPaymentChannelsCard(
            context: context,
            p: p,
            allowEdit: false,
          ),

          const SizedBox(height: 24),

          if (payments.isNotEmpty) ...[
            ProSectionHeader(
              title: AppLocalizations.of(context).tr('paymentHistoryCount', {
                'count': '${payments.length}',
              }),
            ),
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
    final loc = AppLocalizations.of(context);
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
        padding: EdgeInsets.fromLTRB(
          20,
          widget.embedded ? 8 : 16,
          20,
          widget.embedded ? 132 : 40,
        ),
        children: [
          if (widget.embedded) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showIssueInvoiceDialog(context),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 17),
                    label: Text(
                      loc.issueFee,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: p.primary,
                      foregroundColor: p.onPrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      PaymentService.instance.sendMonthlyTuitionReminder(
                        loc.formatMonthYear(DateTime.now()),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(loc.monthlyFeeReminder),
                        ),
                      );
                    },
                    icon: Icon(Icons.notifications_active_outlined,
                        size: 17, color: p.gold),
                    label: Text(
                      loc.sendMonthlyReminders,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: p.gold.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              _buildAdminStatCard(
                p: p,
                title: loc.translate('toReviewTab'),
                value: '${pendingReview.length}',
                icon: Icons.pending_actions_rounded,
                color: p.info,
              ),
              const SizedBox(width: 10),
              _buildAdminStatCard(
                p: p,
                title: loc.overdue,
                value: '${overdueList.length}',
                icon: Icons.warning_amber_rounded,
                color: p.danger,
              ),
              const SizedBox(width: 10),
              _buildAdminStatCard(
                p: p,
                title: loc.approved,
                value: '${approvedList.length}',
                icon: Icons.check_circle_rounded,
                color: p.success,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildPaymentChannelsCard(
            context: context,
            p: p,
            allowEdit: _isSuperAdmin,
          ),
          const SizedBox(height: 22),

          if (pendingReview.isNotEmpty) ...[
            ProSectionHeader(
              title: loc.tr('receiptsAwaitingReviewTitle', {
                'count': '${pendingReview.length}',
              }),
              trailing: ProStatusPill(
                  label: loc.translate('actionRequiredTag'), color: p.info),
            ),
            const SizedBox(height: 12),
            ...pendingReview
                .map((pay) => _buildPendingReviewCard(pay, p)),
            const SizedBox(height: 18),
          ],

          if (overdueList.isNotEmpty) ...[
            ProSectionHeader(
              title: loc.tr('overdueAccountsTitle', {
                'count': '${overdueList.length}',
              }),
              trailing: ProStatusPill(
                  label: loc.translate('pastDueTag'), color: p.danger),
            ),
            const SizedBox(height: 12),
            ...overdueList.map((pay) => _buildOverdueAccountCard(pay, p)),
            const SizedBox(height: 18),
          ],

          ProSectionHeader(
            title: loc.tr('tuitionRecordsTitle', {
              'count': '${payments.length}',
            }),
            trailing: TextButton(
              onPressed: () => _showIssueInvoiceDialog(context),
              child: Text(loc.translate('plusIssueTuition')),
            ),
          ),
          const SizedBox(height: 10),

          if (payments.isEmpty)
            ProEmptyState(
              icon: Icons.payments_outlined,
              title: loc.translate('noTuitionIssuedTitle'),
              message: loc.translate('noTuitionIssuedDesc'),
              actionLabel: loc.translate('createInvoiceAction'),
              onAction: () => _showIssueInvoiceDialog(context),
            )
          else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(AppLocalizations.of(context).allPayments, 'all', p),
                  _buildFilterChip(AppLocalizations.of(context).submitted, 'submitted', p),
                  _buildFilterChip(AppLocalizations.of(context).approved, 'approved', p),
                  _buildFilterChip(AppLocalizations.of(context).rejected, 'rejected', p),
                  _buildFilterChip(AppLocalizations.of(context).pending, 'pending', p),
                  _buildFilterChip(AppLocalizations.of(context).overdue, 'overdue', p),
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
    final loc = AppLocalizations.of(context);
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
                        loc.tr('parentContactLine', {
                          'name': payment.parentName,
                          'contact': '',
                        }),
                        style: TextStyle(fontSize: 12, color: p.inkSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  loc.formatCurrency(payment.amount),
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
                        loc.translate('receiptAttachedInspect'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: p.info,
                        ),
                      ),
                    ),
                    Icon(
                      Directionality.of(context) == TextDirection.rtl
                          ? Icons.chevron_left_rounded
                          : Icons.chevron_right_rounded,
                      size: 18,
                      color: p.info,
                    ),
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
                      loc.translate('rejectAction'),
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
                              loc.tr('paymentApprovedForMsg', {
                                'name': payment.studentName,
                              }),
                            ),
                            backgroundColor: p.success,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: Text(loc.translate('approveAction')),
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
    final loc = AppLocalizations.of(context);
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
                        loc.tr('parentEmailLine', {
                          'name': payment.parentName,
                          'email': payment.parentEmail,
                        }),
                        style: TextStyle(fontSize: 12, color: p.inkSecondary),
                      ),
                    ],
                  ),
                ),
                ProStatusPill(
                    label: loc.translate('overdueUpperTag'), color: p.danger),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await PaymentService.instance
                            .sendOverdueAlertToAdmin(payment);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              loc.tr('overdueAlertDispatchedMsg', {
                                'name': payment.parentName,
                              }),
                            ),
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(SupabaseService.cleanErrorMessage(e)),
                            backgroundColor: p.danger,
                          ),
                        );
                      }
                    },
                    icon: Icon(Icons.notifications_active_rounded,
                        size: 15, color: p.gold),
                    label: Text(
                      loc.translate('sendAlertAction'),
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
                                loc.tr('noLinkedParentMsg', {
                                  'name': payment.studentName,
                                }),
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
                      loc.translate('messageParentAction'),
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
    final loc = AppLocalizations.of(context);
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
                  loc.tr('amountLineLabel', {
                    'amount': payment.amount.toStringAsFixed(0),
                  }),
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
                            loc.translate('viewReceiptAction'),
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
                loc.tr('rejectionReasonQuote', {
                  'reason': '${payment.rejectionReason}',
                }),
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

  Widget _buildPaymentChannelsCard({
    required BuildContext context,
    required AppPalette p,
    required bool allowEdit,
  }) {
    final loc = AppLocalizations.of(context);
    return ValueListenableBuilder<List<CenterPaymentChannel>>(
      valueListenable: PaymentService.instance.paymentChannelsNotifier,
      builder: (context, channels, _) {
        return ProCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_rounded,
                      size: 20, color: p.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      loc.schoolPaymentDetails,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: p.ink,
                      ),
                    ),
                  ),
                  if (allowEdit)
                    TextButton.icon(
                      onPressed: () =>
                          _showEditPaymentChannelsDialog(context, channels),
                      icon: Icon(Icons.edit_outlined,
                          size: 16, color: p.primary),
                      label: Text(
                        loc.translate('editPaymentChannelsAction'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: p.primary,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < channels.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _buildCopyableAccountRow(
                  context: context,
                  p: p,
                  label: loc.translate(channels[i].labelKey),
                  accountNumber: channels[i].accountNumber,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showEditPaymentChannelsDialog(
    BuildContext context,
    List<CenterPaymentChannel> channels,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _EditPaymentChannelsDialog(
        channels: channels,
        hostMessenger: ScaffoldMessenger.of(context),
      ),
    );
  }

  Widget _buildCopyableAccountRow({
    required BuildContext context,
    required AppPalette p,
    required String label,
    required String accountNumber,
  }) {
    final loc = AppLocalizations.of(context);
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
                SnackBar(
                  content: Text(
                    loc.tr('copiedLabelMsg', {'label': label}),
                  ),
                ),
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
                    loc.copyAction,
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
      padding: const EdgeInsetsDirectional.only(end: 8),
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
    final loc = AppLocalizations.of(context);
    Color color = p.gold;
    final label = loc.localizedPaymentStatus(status);

    if (status == 'approved') {
      color = onHero ? const Color(0xFF4ADE80) : p.success;
    } else if (status == 'submitted') {
      color = onHero ? AppColors.goldWarm : p.info;
    } else if (status == 'rejected' || status == 'overdue') {
      color = onHero ? const Color(0xFFFCA5A5) : p.danger;
    }

    return ProStatusPill(label: label, color: color, showDot: true);
  }

  // ===========================================================================
  // DIALOGS
  // ===========================================================================
  void _showIssueInvoiceDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final students = StudentService.instance.allStudents;
    if (students.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(loc.translate('noStudentsEnrolledAlertTitle')),
          content: Text(loc.translate('addOneStudentBeforeTuitionMsg')),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(loc.understood),
            ),
          ],
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (_) => _IssueFeeDialog(
        students: students,
        hostMessenger: ScaffoldMessenger.of(context),
      ),
    );
  }

  void _showUploadReceiptDialog(BuildContext context, MonthlyPayment payment) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UploadReceiptDialog(
        payment: payment,
        hostMessenger: ScaffoldMessenger.of(context),
      ),
    );
  }

  void _showReceiptInspectorDialog(
      BuildContext context, MonthlyPayment payment) {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    final hasValidUrl = StorageService.isValidMediaRef(payment.receiptUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(loc.translate('receiptInspectorTitle')),
            ),
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
                          child: ProSignedImage(
                            mediaRef: payment.receiptUrl!,
                            fit: BoxFit.cover,
                            placeholder: SizedBox(
                              height: 150,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: p.primary,
                                ),
                              ),
                            ),
                            errorWidget: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Icon(Icons.broken_image_rounded,
                                      color: p.inkMuted, size: 32),
                                  const SizedBox(height: 6),
                                  Text(
                                    loc.translate('couldNotLoadReceiptImage'),
                                    style: TextStyle(
                                        fontSize: 12, color: p.inkMuted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          bottom: 8,
                          end: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.zoom_in_rounded,
                                    size: 13, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  loc.translate('tapToZoomHint'),
                                  style: const TextStyle(
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
                      loc.translate('paymentSummaryHeader'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: p.ink,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const Divider(height: 18),
                    _buildReceiptRow(
                        p, loc.translate('beneficiaryLabel'), loc.appName),
                    _buildReceiptRow(
                        p, loc.translate('payerNameLabel'), payment.parentName),
                    _buildReceiptRow(
                        p, loc.roleStudent, payment.studentName),
                    _buildReceiptRow(
                        p, loc.translate('monthShort'), payment.month),
                    _buildReceiptRow(p, loc.translate('amountShort'),
                        loc.formatCurrency(payment.amount, decimals: 2)),
                    _buildReceiptRow(p, loc.translate('statusFieldLabel'),
                        loc.localizedPaymentStatus(payment.status)),
                  ],
                ),
              ),
              if (payment.notes != null && payment.notes!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  loc.tr('parentNoteQuote', {'note': payment.notes!}),
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
                final hostCtx = Navigator.of(context).context;
                Navigator.pop(ctx);
                _showRejectDialog(hostCtx, payment);
              },
              child: Text(
                loc.translate('rejectWithReasonAction'),
                style: TextStyle(color: p.danger),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await PaymentService.instance
                      .approvePayment(paymentId: payment.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(loc.tr('paymentApprovedForMsg', {
                          'name': payment.studentName,
                        })),
                        backgroundColor: p.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(SupabaseService.cleanErrorMessage(e)),
                        backgroundColor: p.danger,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: p.success,
                foregroundColor: Colors.white,
              ),
              child: Text(loc.approvePayment),
            ),
          ] else
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(loc.close),
            ),
        ],
      ),
    );
  }

  void _openFullScreenReceipt(String url) {
    final loc = AppLocalizations.of(context);
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
            title: Text(
              loc.translate('receiptImageTitle'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.6,
              maxScale: 4.0,
              child: ProSignedImage(
                mediaRef: url,
                fit: BoxFit.contain,
                placeholder: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: const Icon(Icons.broken_image_rounded,
                    color: Colors.white54, size: 42),
              ),
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
              textAlign: TextAlign.end,
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
    showDialog<void>(
      context: context,
      builder: (_) => _RejectReceiptDialog(
        payment: payment,
        hostMessenger: ScaffoldMessenger.of(context),
      ),
    );
  }
}

class _IssueFeeDialog extends StatefulWidget {
  final List<Student> students;
  final ScaffoldMessengerState hostMessenger;

  const _IssueFeeDialog({
    required this.students,
    required this.hostMessenger,
  });

  @override
  State<_IssueFeeDialog> createState() => _IssueFeeDialogState();
}

class _IssueFeeDialogState extends State<_IssueFeeDialog> {
  late Student _selectedStudent;
  DateTime _feeStartDate = DateTime.now();
  final _monthCtrl = TextEditingController();
  final _amountCtrl = TextEditingController(text: '50');
  bool _isSaving = false;
  bool _didInitLocalizedDefaults = false;

  @override
  void initState() {
    super.initState();
    _selectedStudent = widget.students.first;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitLocalizedDefaults) {
      _didInitLocalizedDefaults = true;
      _monthCtrl.text = AppLocalizations.of(context).formatMonthYear(DateTime.now());
    }
  }

  @override
  void dispose() {
    _monthCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    final month = _monthCtrl.text.trim();
    final amt = double.tryParse(_amountCtrl.text.trim());
    if (month.isEmpty) {
      widget.hostMessenger.showSnackBar(
        SnackBar(
          content: Text(loc.translate('enterTuitionMonthError')),
          backgroundColor: p.danger,
        ),
      );
      return;
    }
    if (amt == null || amt <= 0) {
      widget.hostMessenger.showSnackBar(
        SnackBar(
          content: Text(loc.translate('enterValidTuitionAmountError')),
          backgroundColor: p.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await PaymentService.instance.createPaymentInvoice(
        studentId: _selectedStudent.id,
        studentName: _selectedStudent.fullName,
        parentId: _selectedStudent.parentId ?? '',
        parentName: _selectedStudent.parentName,
        parentEmail: _selectedStudent.parentEmail ?? '',
        month: month,
        amount: amt,
        dueDate: DateTime.now().add(const Duration(days: 10)),
        feeStartDate: _feeStartDate,
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.hostMessenger.showSnackBar(
        SnackBar(
          content: Text(loc.tr('tuitionIssuedForMsg', {
            'name': _selectedStudent.fullName,
          })),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
      }
      widget.hostMessenger.showSnackBar(
        SnackBar(
          content: Text(SupabaseService.cleanErrorMessage(e)),
          backgroundColor: p.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    final currentMonthExample = loc.formatMonthYear(DateTime.now());
    return AlertDialog(
      title: Text(loc.issueFee),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<Student>(
              value: _selectedStudent,
              isExpanded: true,
              items: widget.students
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          '${s.fullName} (${s.parentName})',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedStudent = val);
                }
              },
              decoration: InputDecoration(labelText: loc.studentsCount),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _monthCtrl,
              decoration: InputDecoration(
                labelText: '${loc.feeMonth} ($currentMonthExample)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '${loc.feeAmount} (${loc.translate('currencyCode')})',
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _feeStartDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (mounted && picked != null) {
                  setState(() => _feeStartDate = picked);
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: p.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${loc.feeStartDate} *',
                          style:
                              TextStyle(fontSize: 11, color: p.inkSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _feeStartDate.toLocal().toString().substring(0, 10),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: p.ink,
                          ),
                        ),
                      ],
                    ),
                    Icon(Icons.calendar_today_rounded,
                        size: 18, color: p.inkSecondary),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(loc.cancel),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(loc.issueFee),
        ),
      ],
    );
  }
}

class _UploadReceiptDialog extends StatefulWidget {
  final MonthlyPayment payment;
  final ScaffoldMessengerState hostMessenger;

  const _UploadReceiptDialog({
    required this.payment,
    required this.hostMessenger,
  });

  @override
  State<_UploadReceiptDialog> createState() => _UploadReceiptDialogState();
}

class _UploadReceiptDialogState extends State<_UploadReceiptDialog> {
  String _selectedMethod = 'Commercial Bank of Ethiopia (CBE)';
  final _noteCtrl = TextEditingController();
  XFile? _selectedReceipt;
  bool _isUploading = false;
  bool _didInitLocalizedDefaults = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitLocalizedDefaults) {
      _didInitLocalizedDefaults = true;
      _noteCtrl.text =
          AppLocalizations.of(context).translate('defaultReceiptNote');
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final receipt = _selectedReceipt;
    if (receipt == null) return;
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    setState(() => _isUploading = true);
    try {
      final bytes = await receipt.readAsBytes();
      final syncedOnline =
          await PaymentService.instance.submitPaymentReceiptOfflineAware(
        paymentId: widget.payment.id,
        receiptBytes: bytes,
        fileName: receipt.name,
        customNote: '$_selectedMethod — ${_noteCtrl.text.trim()}',
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.hostMessenger.showSnackBar(
        SnackBar(
          content: Text(
            syncedOnline
                ? loc.translate('receiptSubmittedSuccessMsg')
                : loc.savedOfflineQueued,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
      }
      widget.hostMessenger.showSnackBar(
        SnackBar(
          content: Text(SupabaseService.cleanErrorMessage(e)),
          backgroundColor: p.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    final receipt = _selectedReceipt;

    return AlertDialog(
      title: Text(loc.translate('uploadPaymentReceiptTitle')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.tr('studentMonthLine', {
                'name': widget.payment.studentName,
                'month': widget.payment.month,
              }),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Text(
              loc.tr('amountDueLine', {
                'amount': widget.payment.amount.toStringAsFixed(0),
              }),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: p.primary,
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _selectedMethod,
              isExpanded: true,
              items: [
                DropdownMenuItem(
                  value: 'Commercial Bank of Ethiopia (CBE)',
                  child: Text(loc.translate('cbeMobileBanking')),
                ),
                DropdownMenuItem(
                  value: 'Telebirr',
                  child: Text(loc.translate('telebirrMobile')),
                ),
                DropdownMenuItem(
                  value: 'Cash Deposit',
                  child: Text(loc.translate('cashSlipLabel')),
                ),
              ],
              onChanged: _isUploading
                  ? null
                  : (val) {
                      if (val != null) {
                        setState(() => _selectedMethod = val);
                      }
                    },
              decoration:
                  InputDecoration(labelText: loc.translate('paymentChannelLabel')),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _isUploading
                  ? null
                  : () async {
                      final picked = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 85,
                      );
                      if (mounted && picked != null) {
                        setState(() => _selectedReceipt = picked);
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
                      receipt != null
                          ? Icons.check_circle_outline_rounded
                          : Icons.add_photo_alternate_rounded,
                      size: 32,
                      color: p.primary,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      receipt != null
                          ? loc.tr('selectedFileLabel', {'name': receipt.name})
                          : loc.translate('tapPickReceiptHint'),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: p.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      receipt != null
                          ? loc.translate('tapToChangeImage')
                          : loc.translate('chooseSlipFromGallery'),
                      style: TextStyle(fontSize: 11, color: p.inkMuted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              enabled: !_isUploading,
              decoration: InputDecoration(
                labelText: loc.translate('transactionRefLabel'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.pop(context),
          child: Text(loc.cancel),
        ),
        ElevatedButton(
          onPressed: (_isUploading || receipt == null) ? null : _submit,
          child: _isUploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(loc.translate('submitReceiptAction')),
        ),
      ],
    );
  }
}

class _RejectReceiptDialog extends StatefulWidget {
  final MonthlyPayment payment;
  final ScaffoldMessengerState hostMessenger;

  const _RejectReceiptDialog({
    required this.payment,
    required this.hostMessenger,
  });

  @override
  State<_RejectReceiptDialog> createState() => _RejectReceiptDialogState();
}

class _RejectReceiptDialogState extends State<_RejectReceiptDialog> {
  final _reasonCtrl = TextEditingController();
  bool _isSaving = false;
  bool _didInitLocalizedDefaults = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitLocalizedDefaults) {
      _didInitLocalizedDefaults = true;
      _reasonCtrl.text =
          AppLocalizations.of(context).translate('defaultRejectReceiptReason');
    }
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) return;
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    setState(() => _isSaving = true);
    try {
      await PaymentService.instance.rejectPayment(
        paymentId: widget.payment.id,
        reason: reason,
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.hostMessenger.showSnackBar(
        SnackBar(
          content: Text(
            loc.tr('paymentRejectedSentMsg', {
              'name': widget.payment.parentName,
            }),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
      }
      widget.hostMessenger.showSnackBar(
        SnackBar(
          content: Text(SupabaseService.cleanErrorMessage(e)),
          backgroundColor: p.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(loc.translate('rejectPaymentReceiptTitle')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.tr('specifyRejectionReasonMsg', {
              'name': widget.payment.parentName,
            }),
            style: const TextStyle(fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: loc.translate('rejectionReasonRequiredLabel'),
              hintText: loc.translate('rejectionReasonHint'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(loc.cancel),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: p.danger,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(loc.translate('confirmRejectionAction')),
        ),
      ],
    );
  }
}

class _EditPaymentChannelsDialog extends StatefulWidget {
  final List<CenterPaymentChannel> channels;
  final ScaffoldMessengerState hostMessenger;

  const _EditPaymentChannelsDialog({
    required this.channels,
    required this.hostMessenger,
  });

  @override
  State<_EditPaymentChannelsDialog> createState() =>
      _EditPaymentChannelsDialogState();
}

class _EditPaymentChannelsDialogState
    extends State<_EditPaymentChannelsDialog> {
  late final TextEditingController _cbeCtrl;
  late final TextEditingController _telebirrCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    String findAccount(String id, String fallback) {
      for (final ch in widget.channels) {
        if (ch.id == id && ch.accountNumber.trim().isNotEmpty) {
          return ch.accountNumber.trim();
        }
      }
      return fallback;
    }

    _cbeCtrl = TextEditingController(
      text: findAccount('cbe', '1000123456789'),
    );
    _telebirrCtrl = TextEditingController(
      text: findAccount('telebirr', '+251 91 123 4567'),
    );
  }

  @override
  void dispose() {
    _cbeCtrl.dispose();
    _telebirrCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final cbe = _cbeCtrl.text.trim();
    final telebirr = _telebirrCtrl.text.trim();
    if (cbe.isEmpty || telebirr.isEmpty) return;

    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    setState(() => _isSaving = true);
    try {
      await PaymentService.instance.savePaymentChannels(
        cbeNumber: cbe,
        telebirrNumber: telebirr,
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.hostMessenger.showSnackBar(
        SnackBar(
          content: Text(loc.translate('paymentChannelsSavedMsg')),
          backgroundColor: p.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      widget.hostMessenger.showSnackBar(
        SnackBar(
          content: Text(SupabaseService.cleanErrorMessage(e)),
          backgroundColor: p.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(loc.translate('editPaymentChannelsTitle')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _cbeCtrl,
              enabled: !_isSaving,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: loc.translate('cbeBankName'),
                prefixIcon: const Icon(Icons.account_balance_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _telebirrCtrl,
              enabled: !_isSaving,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: loc.translate('telebirrAccountLabel'),
                prefixIcon: const Icon(Icons.phone_android_rounded, size: 18),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(loc.cancel),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: p.primary,
            foregroundColor: p.onPrimary,
          ),
          child: Text(
            _isSaving
                ? loc.savingProgress
                : loc.translate('saveAccountsAction'),
          ),
        ),
      ],
    );
  }
}
