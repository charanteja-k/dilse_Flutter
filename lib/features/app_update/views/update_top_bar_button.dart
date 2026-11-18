import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/extensions/context_extensions.dart';
import '../viewmodels/update_viewmodel.dart';
import 'update_hub_sheet.dart';

/// Top-bar button always available to check GitHub for newer releases,
/// switch temporary GitHub test repos, and install updates inline.
/// Adheres strictly to AGENTS.md Invariants 1, 2 & 3.
class UpdateTopBarButton extends StatelessWidget {
  const UpdateTopBarButton({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UpdateViewModel>();
    final hasUpdate = vm.hasAvailableUpdate;
    final tagLabel = vm.latestUpdate?.tagName;

    return Tooltip(
      message: hasUpdate && tagLabel != null
          ? 'Update available: $tagLabel'
          : 'Check GitHub updates',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          UpdateHubSheet.show(context);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: context.sizes.avatarSm,
              height: context.sizes.avatarSm,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.cardDarkSurface,
                border: Border.all(
                  color: hasUpdate
                      ? context.colors.brandRuby
                      : context.colors.solidMatteBorder,
                  width: context.sizes.borderThin,
                ),
              ),
              child: Center(
                child: vm.isChecking
                    ? SizedBox(
                        width: context.sizes.iconSm,
                        height: context.sizes.iconSm,
                        child: CircularProgressIndicator(
                          strokeWidth: context.spacing.xxs,
                          color: context.colors.brandRuby,
                        ),
                      )
                    : Icon(
                        Icons.system_update_rounded,
                        color: hasUpdate
                            ? context.colors.brandRuby
                            : context.colors.textPrimary,
                        size: context.sizes.iconSm,
                      ),
              ),
            ),

            // Notification dot when a newer GitHub release is detected
            if (hasUpdate)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: context.sizes.badgeDotSize,
                  height: context.sizes.badgeDotSize,
                  decoration: BoxDecoration(
                    color: context.colors.brandRuby,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.colors.oledBackground,
                      width: context.sizes.borderThin,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
