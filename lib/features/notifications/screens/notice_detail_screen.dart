import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:secondary_sales/core/constants.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/data/models/notifications/app_notice.dart';

class NoticeDetailScreen extends StatelessWidget {
  const NoticeDetailScreen({
    super.key,
    required this.notice,
  });

  final AppNotice notice;

  Future<void> _openAttachment(BuildContext context, NoticeAttachment attachment) async {
    final fullUrl = attachment.url.startsWith('http')
        ? attachment.url
        : '${AppConstants.baseUrl}${attachment.url}';
    final uri = Uri.tryParse(fullUrl);
    if (uri != null) {
      final ok = await canLaunchUrl(uri);
      if (ok) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open ${attachment.name}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = notice.createdAt != null
        ? DateFormat('EEEE, MMM d, y • h:mm a').format(notice.createdAt!)
        : '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(
          'Notice Detail',
          style: TextStyle(
            color: AppColors.primaryStrong,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Channel & Date Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.campaign_outlined,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        notice.channelName,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (timeStr.isNotEmpty)
                  Text(
                    timeStr,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Subject / Title
            if (notice.subject.isNotEmpty) ...[
              Text(
                notice.subject,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Author Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    backgroundImage: notice.authorAvatarUrl != null
                        ? NetworkImage(
                            notice.authorAvatarUrl!.startsWith('http')
                                ? notice.authorAvatarUrl!
                                : '${AppConstants.baseUrl}${notice.authorAvatarUrl}',
                          )
                        : null,
                    child: notice.authorAvatarUrl == null
                        ? Text(
                            notice.authorName.isNotEmpty
                                ? notice.authorName[0].toUpperCase()
                                : 'A',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notice.authorName,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Posted in #${notice.channelName}',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Body Content
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: SelectableText(
                notice.plainTextBody.isNotEmpty
                    ? notice.plainTextBody
                    : (notice.body.isNotEmpty ? notice.body : 'No content'),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Attachments Section
            if (notice.hasAttachments) ...[
              Text(
                'Attachments (${notice.attachments.length})',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              ...notice.attachments.map((att) => _buildAttachmentCard(context, att)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentCard(BuildContext context, NoticeAttachment attachment) {
    IconData iconData = Icons.insert_drive_file_outlined;
    Color iconColor = AppColors.primary;

    if (attachment.isPdf) {
      iconData = Icons.picture_as_pdf_outlined;
      iconColor = Colors.red.shade700;
    } else if (attachment.isImage) {
      iconData = Icons.image_outlined;
      iconColor = Colors.green.shade700;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.12),
          child: Icon(iconData, color: iconColor, size: 22),
        ),
        title: Text(
          attachment.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: attachment.formattedSize.isNotEmpty
            ? Text(
                attachment.formattedSize,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              )
            : null,
        trailing: IconButton(
          icon: Icon(Icons.download_rounded, color: AppColors.primary),
          onPressed: () => _openAttachment(context, attachment),
        ),
        onTap: () => _openAttachment(context, attachment),
      ),
    );
  }
}
