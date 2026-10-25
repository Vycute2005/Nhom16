import 'package:hcm_explorer/widgets/app_ui.dart';

import '../services/favorites_store.dart';
import 'account_access_screen.dart';
import 'favorites_screen.dart';
import 'profile_screen_v2.dart';

class ProfileScreen extends ProfileScreenV2 {
  const ProfileScreen({super.key});
}

class LegacyProfileScreen extends StatelessWidget {
  const LegacyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Cá nhân',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: favoritesStore,
          builder: (context, _) {
            final savedCount = favoritesStore.entries.length;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                AnimatedBuilder(
                  animation: userSession,
                  builder: (context, _) {
                    final isSignedIn = userSession.isSignedIn;
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE8DED0)),
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: const Color(0xFF0F5B49),
                            child: Icon(
                              isSignedIn ? Icons.person : Icons.person_outline,
                              size: 38,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isSignedIn ? 'Tài khoản của bạn' : 'Khách',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isSignedIn && userSession.email != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              userSession.email!,
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                          if (!isSignedIn) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => const AccountAccessScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.login),
                              label: const Text('Đăng nhập / Đăng ký'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0F5B49),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const FavoritesScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE8DED0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF0EA),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              color: Color(0xFFB83B26),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Đã lưu / Yêu thích',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$savedCount mục đã lưu',
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

