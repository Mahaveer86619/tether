import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../tailscale/tailscale_banner.dart';
import '../theme/theme.dart';
import 'connection_doctor.dart';

/// The notices at the top of the app about reaching the hub. While the doctor
/// is checking or mending nothing shows; when it could not fix the connection
/// it says what is wrong and what to do; otherwise Tailscale's own banner
/// speaks for a hub that stays out of reach.
class ConnectionBanners extends StatelessWidget {
  const ConnectionBanners({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ConnectionDoctor>().state;
    return switch (s.phase) {
      DoctorPhase.checking || DoctorPhase.mending => const SizedBox.shrink(),
      DoctorPhase.failed => _Problem(problem: s.problem!),
      DoctorPhase.idle => const TailscaleBanner(),
    };
  }
}

class _Problem extends StatelessWidget {
  const _Problem({required this.problem});

  final ConnectionProblem problem;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final doctor = context.read<ConnectionDoctor>();
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final tailscale = switch (problem.kind) {
      ProblemKind.tailscaleOff || ProblemKind.tailscaleLogin || ProblemKind.tailscaleStuck => true,
      _ => false,
    };
    return Material(
      key: const Key('connection-problem'),
      color: c.warning.withValues(alpha: 0.10),
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
        padding: EdgeInsets.fromLTRB(narrow ? 12 : 20, 10, 6, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_off_rounded, size: 18, color: c.warning),
                const SizedBox(width: 10),
                Expanded(child: Text(problem.title, key: const Key('connection-problem-title'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                IconButton(key: const Key('connection-problem-dismiss'), tooltip: 'Hide', visualDensity: VisualDensity.compact, icon: const Icon(Icons.close_rounded, size: 18), onPressed: doctor.dismiss),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 28, right: 12, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, step) in problem.steps.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text('${i + 1}. $step', style: TextStyle(fontSize: 13, color: c.muted)),
                    ),
                ],
              ),
            ),
            Wrap(
              children: [
                if (tailscale) TextButton(key: const Key('connection-open-tailscale'), onPressed: doctor.openTailscale, child: const Text('Open Tailscale')),
                TextButton(key: const Key('connection-try-again'), onPressed: doctor.run, child: const Text('Try again')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
