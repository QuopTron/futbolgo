import 'package:flutter/material.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatelessWidget {
  final AppVersion update;
  final VoidCallback onDismiss;
  final VoidCallback onUpdate;

  const UpdateDialog({
    super.key,
    required this.update,
    required this.onDismiss,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final releaseNotes = update.releaseNotes ?? '';
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0E1A), Color(0x000A0E1A)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Header(),
            const SizedBox(height: 8),
            const Text(
              '¡Hola! Nueva versión disponible',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 12),
            Content(releaseNotes: releaseNotes, update: update),
            const SizedBox(height: 24),
              Actions(onUpdate: onUpdate, onDismiss: onDismiss),
            ],
          ),
        ),
      ),
    );
  }
}

class Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue, Colors.cyan],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.system_update_alt_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Actualización disponible',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Nueva versión disponible',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class Content extends StatelessWidget {
  final String releaseNotes;
  final AppVersion update;

  const Content({required this.releaseNotes, required this.update});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.new_releases_rounded,
                size: 16,
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              Text(
                'Versión 1.0.0 → ${update.version}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          if (releaseNotes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _formatReleaseNotes(releaseNotes),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatReleaseNotes(String notes) {
    final lines = notes.split('\n');
    final formattedLines = lines
        .where((line) => line.isNotEmpty)
        .map((line) => line.startsWith('-') || line.startsWith('*')
            ? line.substring(1).trim()
            : line.trim())
        .take(5)
        .toList();
    
    if (lines.length > 5) {
      return '${formattedLines.join('\n• ')}\n...';
    }
    
    return formattedLines.join('\n• ');
  }
}

class Actions extends StatelessWidget {
  final VoidCallback onUpdate;
  final VoidCallback onDismiss;

  const Actions({
    required this.onUpdate,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildButton(
            context: context,
            text: 'Más tarde',
            isPrimary: false,
            onPressed: onDismiss,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildButton(
            context: context,
            text: 'Actualizar ahora',
            isPrimary: true,
            onPressed: onUpdate,
          ),
        ),
      ],
    );
  }

  Widget _buildButton({
    required BuildContext context,
    required String text,
    required bool isPrimary,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.blue, Colors.cyan],
                )
              : null,
          color: isPrimary
              ? null
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isPrimary
                  ? Colors.white
                  : Colors.grey[400],
            ),
          ),
        ),
      ),
    );
  }
}
