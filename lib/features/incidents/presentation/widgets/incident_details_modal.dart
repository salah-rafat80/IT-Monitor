import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/entities/incident_entity.dart';
import 'incident_status_chip.dart';

class IncidentDetailsModal extends StatefulWidget {
  final IncidentEntity incident;
  final UserRole userRole;
  final String currentUsername;
  final Function(int id, String username, String? note)? onAcknowledge;
  final Function(int id, String note)? onAddNote;

  const IncidentDetailsModal({
    super.key,
    required this.incident,
    required this.userRole,
    required this.currentUsername,
    this.onAcknowledge,
    this.onAddNote,
  });

  @override
  State<IncidentDetailsModal> createState() => _IncidentDetailsModalState();
}

class _IncidentDetailsModalState extends State<IncidentDetailsModal> {
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _ackNoteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    _ackNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inc = widget.incident;
    final isAdmin = widget.userRole == UserRole.admin;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final displayOwner =
        inc.ownerName.trim().isEmpty ||
            inc.ownerName.trim().toLowerCase() == 'unassigned'
        ? 'Unassigned'
        : inc.ownerName.trim();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 650,
        constraints: const BoxConstraints(maxHeight: 750),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.warning_rounded,
                          color: Color(0xFFEF4444),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Incident #${inc.id} • ${inc.deviceName}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$displayOwner (${inc.department}) • ${inc.deviceIp}',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withValues(alpha: 0.7),
                              fontStyle: displayOwner == 'Unassigned'
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IncidentSeverityChip(severity: inc.severity),
                      const SizedBox(width: 8),
                      IncidentStatusChip(status: inc.status),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 32),

              // Multi-Device Location Correlation Banner if present
              if (inc.correlationMessage != null &&
                  inc.correlationMessage!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.hub_rounded,
                        color: Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Location Correlation Signal: ${inc.correlationMessage}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Metadata Details
              Text(
                'Incident & Device Identity',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  children: [
                    _buildMetaRow('Assigned Person', displayOwner),
                    const Divider(height: 16),
                    _buildMetaRow('Department', inc.department),
                    const Divider(height: 16),
                    _buildMetaRow('Device Name', inc.deviceName),
                    const Divider(height: 16),
                    _buildMetaRow('Device IP', inc.deviceIp),
                    const Divider(height: 16),
                    _buildMetaRow('Office / Location', inc.location ?? '-'),
                    const Divider(height: 16),
                    _buildMetaRow('Incident Type', inc.incidentType.name),
                    const Divider(height: 16),
                    _buildMetaRow(
                      'Started Timestamp',
                      dateFormat.format(inc.startedAt),
                    ),
                    const Divider(height: 16),
                    _buildMetaRow(
                      'Resolved Timestamp',
                      inc.resolvedAt != null
                          ? dateFormat.format(inc.resolvedAt!)
                          : 'Active Condition',
                    ),
                    const Divider(height: 16),
                    _buildMetaRow(
                      'Acknowledged At',
                      inc.acknowledgedAt != null
                          ? dateFormat.format(inc.acknowledgedAt!)
                          : 'Not Acknowledged',
                    ),
                    const Divider(height: 16),
                    _buildMetaRow(
                      'Acknowledged By User',
                      inc.acknowledgedBy ?? '-',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Notes & Audit History Section
              Text(
                'Incident Audit Notes',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  inc.notes != null && inc.notes!.isNotEmpty
                      ? inc.notes!
                      : 'No notes recorded for this incident.',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ),

              // Admin Acknowledge & Note Actions
              if (isAdmin) ...[
                const SizedBox(height: 24),
                if (inc.status == IncidentStatusEnum.active) ...[
                  TextField(
                    controller: _ackNoteController,
                    decoration: const InputDecoration(
                      hintText: 'Optional acknowledgment note...',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        widget.onAcknowledge?.call(
                          inc.id,
                          widget.currentUsername,
                          _ackNoteController.text,
                        );
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text(
                        'Acknowledge Incident (Does Not Resolve)',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Add Note Form
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _noteController,
                        decoration: const InputDecoration(
                          hintText: 'Add progress or diagnostic note...',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        if (_noteController.text.trim().isNotEmpty) {
                          widget.onAddNote?.call(inc.id, _noteController.text);
                          _noteController.clear();
                        }
                      },
                      icon: const Icon(Icons.note_add_rounded, size: 18),
                      label: const Text('Add Note'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
