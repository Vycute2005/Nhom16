import 'package:hcm_explorer/widgets/app_ui.dart';

import '../screens/account_access_screen.dart';
import '../services/favorites_store.dart';

Future<bool> toggleFavoriteWithLogin(
  BuildContext context,
  FavoriteEntry entry,
) async {
  final isSaved = favoritesStore.contains(entry.key);

  if (!isSaved) {
    final isSignedIn = await requestAccountAccess(context);
    if (!isSignedIn || !context.mounted) return false;
  }
  try {
    if (isSaved) {
      await favoritesStore.remove(entry.key);
      return false;
    }
    await favoritesStore.add(entry);
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không đồng bộ được yêu thích: $error')),
      );
    }
    return false;
  }
}

class FavoriteButton extends StatelessWidget {
  final FavoriteEntry entry;
  final Color color;

  const FavoriteButton({
    super.key,
    required this.entry,
    this.color = const Color(0xFFB83B26),
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: favoritesStore,
        builder: (context, _) {
          final isSaved = favoritesStore.contains(entry.key);
          return IconButton(
            tooltip: AppTranslations.translate(isSaved ? 'Bỏ yêu thích' : 'Thêm vào yêu thích'),
            visualDensity: VisualDensity.compact,
            onPressed: () => toggleFavoriteWithLogin(context, entry),
            icon: Icon(
              isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isSaved ? color : Colors.black45,
            ),
          );
        },
      );
}
