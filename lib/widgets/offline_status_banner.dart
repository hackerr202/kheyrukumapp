import 'package:flutter/material.dart';
import '../core/localization/app_localizations.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/offline_sync_service.dart';
import '../core/theme/app_colors.dart';
import 'pro_ui_kit.dart';

/// Calm non-blocking offline & auto-sync banner mounted in Dashboard & Chat screens.
class OfflineStatusBanner extends StatelessWidget {
  const OfflineStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.instance.isOnlineNotifier,
      builder: (context, isOnline, _) {
        return ValueListenableBuilder<OfflineSyncStatus>(
          valueListenable: OfflineSyncService.instance.statusNotifier,
          builder: (context, status, _) {
            final p = AppColors.of(context);
            final loc = AppLocalizations.of(context);

            final bool shouldShow = !isOnline ||
                status.isSyncing ||
                status.failedCount > 0 ||
                status.pendingCount > 0 ||
                status.justSynced;

            if (!shouldShow) {
              return const SizedBox.shrink();
            }

            Color toneColor;
            IconData? icon;
            String text;
            bool showSpinner = false;

            if (status.isSyncing) {
              toneColor = p.primary;
              text = status.pendingCount > 0
                  ? '${loc.syncingPendingChanges} (${status.pendingCount})'
                  : loc.syncingPendingChanges;
              showSpinner = true;
            } else if (status.failedCount > 0) {
              toneColor = p.danger;
              icon = Icons.error_outline_rounded;
              text = '${status.failedCount} ${loc.failedSyncTapToReview}';
            } else if (!isOnline && status.pendingCount > 0) {
              toneColor = p.warning;
              icon = Icons.cloud_off_rounded;
              text =
                  '${loc.statusOffline} — ${status.pendingCount} ${loc.offlinePendingChanges}. ${loc.offlineWillSync}.';
            } else if (!isOnline) {
              toneColor = p.warning;
              icon = Icons.wifi_off_rounded;
              text = loc.offlineModeViewingSaved;
            } else if (status.pendingCount > 0) {
              toneColor = p.primary;
              icon = Icons.schedule_rounded;
              text =
                  '${status.pendingCount} ${loc.offlinePendingChanges} — ${loc.syncNow}';
            } else {
              toneColor = p.success;
              icon = Icons.cloud_done_rounded;
              text = '${loc.allChangesSynced} ✓';
            }

            return AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 6),
                child: Material(
                  color: toneColor.withOpacity(p.isDark ? 0.18 : 0.11),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () => OfflineSyncQueueSheet.show(context),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: toneColor.withOpacity(0.38),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (showSpinner)
                            SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: toneColor,
                              ),
                            )
                          else
                            Icon(icon, size: 16, color: toneColor),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: p.ink,
                              ),
                            ),
                          ),
                          if (status.totalActionableCount > 0 || !isOnline) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Directionality.of(context) == TextDirection.rtl
                                  ? Icons.chevron_left_rounded
                                  : Icons.chevron_right_rounded,
                              size: 16,
                              color: p.inkSecondary,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Interactive Pending Offline Queue Inspector & Manual Sync Sheet.
class OfflineSyncQueueSheet extends StatelessWidget {
  const OfflineSyncQueueSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const OfflineSyncQueueSheet(),
    );
  }

  IconData _entityIcon(String entityType) {
    switch (entityType) {
      case OfflineEntityTypes.attendance:
        return Icons.fact_check_rounded;
      case OfflineEntityTypes.weeklyReport:
      case OfflineEntityTypes.hifz:
        return Icons.auto_stories_rounded;
      case OfflineEntityTypes.homeworkAssignment:
      case OfflineEntityTypes.homeworkSubmission:
        return Icons.menu_book_rounded;
      case OfflineEntityTypes.absenceRequest:
        return Icons.event_busy_rounded;
      case OfflineEntityTypes.chatMessage:
        return Icons.chat_bubble_outline_rounded;
      case OfflineEntityTypes.paymentReceipt:
        return Icons.receipt_long_rounded;
      case OfflineEntityTypes.announcement:
        return Icons.campaign_rounded;
      case OfflineEntityTypes.student:
        return Icons.person_add_alt_1_rounded;
      default:
        return Icons.sync_rounded;
    }
  }

  String _formatTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);

    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.instance.isOnlineNotifier,
      builder: (context, isOnline, _) {
        return ValueListenableBuilder<OfflineSyncStatus>(
          valueListenable: OfflineSyncService.instance.statusNotifier,
          builder: (context, status, _) {
            return ValueListenableBuilder<List<OfflineMutation>>(
              valueListenable: OfflineSyncService.instance.mutationsNotifier,
              builder: (context, mutations, _) {
                final lastSyncedLabel = status.lastSyncedAt != null
                    ? '${loc.lastSynced}: ${_formatTimestamp(status.lastSyncedAt!)}'
                    : loc.neverSynced;

                return ProBottomSheetShell(
                  title: loc.syncAndOfflineStorage,
                  subtitle: loc.syncQueueSubtitle,
                  icon: Icons.cloud_sync_rounded,
                  iconColor: isOnline ? p.primary : p.warning,
                  heightFactor: 0.78,
                  trailingAction: IconButton(
                    icon: Icon(Icons.close_rounded, color: p.inkSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  child: Column(
                    children: [
                      // Connection & Sync Controls Bar
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          18,
                          14,
                          18,
                          10,
                        ),
                        child: ProCard(
                          padding: const EdgeInsets.all(14),
                          backgroundColor: p.canvas,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ProStatusPill(
                                    label: isOnline
                                        ? loc.statusOnline
                                        : loc.statusOffline,
                                    color: isOnline ? p.success : p.warning,
                                    showDot: true,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      lastSyncedLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: p.inkSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (mutations.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: status.isSyncing
                                            ? null
                                            : () async {
                                                final ok =
                                                    await ConnectivityService
                                                        .instance
                                                        .checkNow();
                                                if (!ok && context.mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        loc.internetRequiredAction,
                                                      ),
                                                      backgroundColor:
                                                          p.warning,
                                                    ),
                                                  );
                                                  return;
                                                }
                                                await OfflineSyncService
                                                    .instance
                                                    .syncPendingMutations();
                                              },
                                        icon: status.isSyncing
                                            ? SizedBox(
                                                width: 15,
                                                height: 15,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: p.onPrimary,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.sync_rounded,
                                                size: 16,
                                              ),
                                        label: Text(
                                          status.isSyncing
                                              ? loc.syncingStatus
                                              : loc.syncNow,
                                        ),
                                      ),
                                    ),
                                    if (status.failedCount > 0) ...[
                                      const SizedBox(width: 10),
                                      OutlinedButton.icon(
                                        onPressed: status.isSyncing
                                            ? null
                                            : () => OfflineSyncService.instance
                                                .retryAllFailed(),
                                        icon: const Icon(
                                          Icons.refresh_rounded,
                                          size: 16,
                                        ),
                                        label: Text(loc.retryAll),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Queue Items or Clean Caught-Up State
                      Expanded(
                        child: mutations.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(24),
                                child: ProEmptyState(
                                  icon: Icons.cloud_done_rounded,
                                  title: loc.noPendingChanges,
                                  message: loc.allCaughtUpMessage,
                                  accentColor: p.success,
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsetsDirectional.fromSTEB(
                                  18,
                                  4,
                                  18,
                                  24,
                                ),
                                itemCount: mutations.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final mut = mutations[index];
                                  final tone = mut.isFailed
                                      ? p.danger
                                      : (mut.isSyncing
                                          ? p.primary
                                          : p.warning);
                                  final statusText = mut.isFailed
                                      ? loc.rejected
                                      : (mut.isSyncing
                                          ? loc.syncingStatus
                                          : loc.pending);

                                  return ProCard(
                                    padding: const EdgeInsets.all(14),
                                    borderColor: mut.isFailed
                                        ? p.danger.withOpacity(0.45)
                                        : null,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: tone.withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                _entityIcon(mut.entityType),
                                                size: 18,
                                                color: tone,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    mut.displayLabel ??
                                                        mut.entityType,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 13.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: p.ink,
                                                    ),
                                                  ),
                                                  Text(
                                                    _formatTimestamp(
                                                      mut.createdAt,
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: p.inkMuted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            ProStatusPill(
                                              label: statusText,
                                              color: tone,
                                              showDot: true,
                                            ),
                                          ],
                                        ),
                                        if (mut.lastError != null &&
                                            mut.lastError!
                                                .trim()
                                                .isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: p.danger
                                                  .withOpacity(0.08),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              mut.lastError!,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: p.danger,
                                              ),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            if (mut.isFailed) ...[
                                              TextButton.icon(
                                                onPressed: () =>
                                                    OfflineSyncService.instance
                                                        .retryFailed(mut.id),
                                                icon: const Icon(
                                                  Icons.refresh_rounded,
                                                  size: 16,
                                                ),
                                                label: Text(loc.retry),
                                              ),
                                              const SizedBox(width: 4),
                                            ],
                                            TextButton.icon(
                                              onPressed: mut.isSyncing
                                                  ? null
                                                  : () => OfflineSyncService
                                                      .instance
                                                      .discardMutation(mut.id),
                                              style: TextButton.styleFrom(
                                                foregroundColor: p.danger,
                                              ),
                                              icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                size: 16,
                                              ),
                                              label: Text(loc.discard),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
