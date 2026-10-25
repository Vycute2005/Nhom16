import 'package:file_picker/file_picker.dart';
import 'package:hcm_explorer/widgets/app_ui.dart';

import 'account_access_screen.dart';
import '../services/auth_api_service.dart';
import '../services/favorites_store.dart';
import '../services/upload_service.dart';
import '../widgets/app_image.dart';

const _green = Color(0xFF0F5B49);
const _red = Color(0xFFB83B26);
const _border = Color(0xFFE8DED0);

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> with AppLocaleAwareState<CommunityScreen> {
  final _api = AuthApiService();
  bool _popular = false;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _posts = const [];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts = await _api.getCommunityPosts(
        popular: _popular,
        token: userSession.token,
      );
      if (mounted) setState(() => _posts = posts);
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Không thể tải bài chia sẻ lúc này.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _write() async {
    if (!await requestAccountAccess(context) || !mounted) return;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const CommunityReviewScreen()),
    );
    if (created == true && mounted) await _loadPosts();
  }

  Future<void> _openPost(Map<String, dynamic> post) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => CommunityPostScreen(post: post)),
    );
    if (changed == true && mounted) await _loadPosts();
  }

  void _selectSort(bool popular) {
    if (_popular == popular) return;
    setState(() => _popular = popular);
    _loadPosts();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width =
              constraints.maxWidth > 760 ? 720.0 : constraints.maxWidth;
          return Center(
            child: SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(22, 18, 22, 14),
                    child: Text('Góc chia sẻ',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF202522))),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Row(
                      children: [
                        _SortChip(
                            label: 'Mới nhất',
                            selected: !_popular,
                            onTap: () => _selectSort(false)),
                        const SizedBox(width: 10),
                        _SortChip(
                            label: 'Phổ biến',
                            selected: _popular,
                            onTap: () => _selectSort(true)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: _loading && _posts.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null && _posts.isEmpty
                            ? _LoadError(message: _error!, onRetry: _loadPosts)
                            : RefreshIndicator(
                                onRefresh: _loadPosts,
                                child: ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding:
                                      const EdgeInsets.fromLTRB(22, 0, 22, 12),
                                  itemCount: _posts.isEmpty ? 1 : _posts.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 14),
                                  itemBuilder: (context, index) {
                                    if (_posts.isEmpty) {
                                      return const Padding(
                                        padding: EdgeInsets.only(top: 48),
                                        child: Center(
                                            child: Text(
                                                'Chưa có bài chia sẻ. Hãy đăng đánh giá đầu tiên nhé!',
                                                textAlign: TextAlign.center)),
                                      );
                                    }
                                    final post = _posts[index];
                                    return _PostCard(
                                        post: post,
                                        onTap: () => _openPost(post));
                                  },
                                ),
                              ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                    child: SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: _write,
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text('Chia sẻ trải nghiệm',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        style: FilledButton.styleFrom(
                            backgroundColor: _red,
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Tải lại')),
          ]),
        ),
      );
}

class _SortChip extends StatelessWidget {
  const _SortChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? _green : Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: selected ? _green : _border)),
            child: Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF343936),
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal)),
          ),
        ),
      );
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.onTap});
  final Map<String, dynamic> post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = (post['placeName'] ?? 'Đánh giá địa điểm').toString();
    final author = (post['authorName'] ?? 'Thành viên').toString();
    final content = (post['content'] ?? '').toString();
    final isHidden = post['isHidden'] == true || post['isHidden']?.toString() == '1';
    final rating = int.tryParse((post['rating'] ?? 0).toString()) ?? 0;
    final comments = int.tryParse((post['commentCount'] ?? 0).toString()) ?? 0;
    final likes = int.tryParse((post['likesCount'] ?? 0).toString()) ?? 0;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: AppImage(
                  source: (post['imageUrl'] ?? '').toString(),
                  width: double.infinity,
                  height: 164,
                  fallbackIcon: Icons.restaurant_rounded),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF202522)))),
              const Icon(Icons.star_rounded,
                  color: Color(0xFFE5AA25), size: 19),
              Text(' $rating/5',
                  style: const TextStyle(
                      color: Color(0xFF9A6B0B), fontWeight: FontWeight.w600)),
            ]),
            if (isHidden) ...[
              const SizedBox(height: 5),
              const Text(
                'Bài đánh giá này đã bị quản trị viên tắt.',
                style: TextStyle(color: Color(0xFF77736D), fontStyle: FontStyle.italic),
              ),
            ] else if (content.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: Color(0xFF4C514E), height: 1.35)),
            ],
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: Text(
                      'Bởi $author · ${_relativeDate(post['createdAt'])}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF77736D)))),
              const Icon(Icons.thumb_up_alt_outlined,
                  size: 14, color: Color(0xFF77736D)),
              const SizedBox(width: 3),
              Text('$likes', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 12),
              const Icon(Icons.mode_comment_outlined,
                  size: 14, color: Color(0xFF77736D)),
              const SizedBox(width: 3),
              Text('$comments', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Color(0xFF77736D)),
            ]),
          ]),
        ),
      ),
    );
  }
}

String _relativeDate(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  if (date == null) return 'mới đăng';
  final elapsed = DateTime.now().difference(date);
  if (elapsed.inMinutes < 1) return 'vừa xong';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes} phút trước';
  if (elapsed.inDays < 1) return '${elapsed.inHours} giờ trước';
  if (elapsed.inDays == 1) return '1 ngày trước';
  return '${elapsed.inDays} ngày trước';
}

class CommunityPostScreen extends StatefulWidget {
  const CommunityPostScreen({super.key, required this.post});
  final Map<String, dynamic> post;

  @override
  State<CommunityPostScreen> createState() => _CommunityPostScreenState();
}

class _CommunityPostScreenState extends State<CommunityPostScreen> with AppLocaleAwareState<CommunityPostScreen> {
  final _api = AuthApiService();
  final _replyController = TextEditingController();
  Map<String, dynamic>? _post;
  List<Map<String, dynamic>> _comments = const [];
  Map<String, dynamic>? _replyingTo;
  bool _loading = true;
  bool _sending = false;
  bool _changed = false;
  String? _error;

  String get _postId => (widget.post['id'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadPost();
  }

  @override
  void dispose() {
    _api.close();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadPost() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.getCommunityPost(
          postId: _postId, token: userSession.token);
      final post = result['post'];
      final comments = result['comments'];
      if (mounted) {
        setState(() {
          if (post is Map) _post = Map<String, dynamic>.from(post);
          _comments = comments is List
              ? comments
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
              : const [];
        });
      }
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể tải bình luận lúc này.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reply(Map<String, dynamic> comment) async {
    if (!await requestAccountAccess(context) || !mounted) return;
    setState(() => _replyingTo = comment);
    FocusScope.of(context).requestFocus();
  }

  Future<void> _sendComment() async {
    final content = _replyController.text.trim();
    if (content.isEmpty || _sending) return;
    if (!await requestAccountAccess(context) || !mounted) return;
    final token = userSession.token;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Vui lòng đăng nhập lại để bình luận.')));
      return;
    }
    setState(() => _sending = true);
    try {
      await _api.addCommunityComment(
        token: token,
        postId: _postId,
        content: content,
        parentCommentId: _replyingTo?['id']?.toString(),
      );
      _replyController.clear();
      setState(() {
        _replyingTo = null;
        _changed = true;
      });
      await _loadPost();
    } on AuthApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể gửi bình luận lúc này.')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _post ?? widget.post;
    final author = (post['authorName'] ?? 'Thành viên').toString();
    final rating = int.tryParse((post['rating'] ?? 0).toString()) ?? 0;
    final isPostHidden = post['isHidden'] == true || post['isHidden']?.toString() == '1';
    final parentAuthors = <String, String>{
      for (final comment in _comments)
        (comment['id'] ?? '').toString():
            (comment['authorName'] ?? 'Thành viên').toString(),
    };

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_changed);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bài đánh giá'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (_error != null)
                MaterialBanner(content: Text(_error!), actions: [
                  TextButton(
                      onPressed: _loadPost, child: const Text('Tải lại')),
                ]),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: AppImage(
                        source: (post['imageUrl'] ?? '').toString(),
                        width: double.infinity,
                        height: 220,
                        fallbackIcon: Icons.restaurant_rounded,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text((post['placeName'] ?? 'Đánh giá địa điểm').toString(),
                        style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF202522))),
                    const SizedBox(height: 5),
                    Row(children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFE5AA25)),
                      Expanded(
                          child: Text(
                        ' $rating/5 · Bởi $author · ${_relativeDate(post['createdAt'])}',
                        style: const TextStyle(color: Color(0xFF77736D)),
                      )),
                    ]),
                    const SizedBox(height: 14),
                    Text(
                      isPostHidden
                          ? 'Bài đánh giá này đã bị quản trị viên tắt.'
                          : (post['content'] ?? '').toString(),
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    Row(children: [
                      const Expanded(
                          child: Text('Bình luận',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold))),
                      Text('${_comments.length}'),
                    ]),
                    const SizedBox(height: 8),
                    if (_loading && _comments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(18),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_comments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                            'Chưa có bình luận. Hãy mở đầu cuộc trò chuyện.'),
                      )
                    else
                      ..._comments.map((comment) {
                        final parentId = comment['parentCommentId']?.toString();
                        return _CommentTile(
                          comment: comment,
                          parentAuthor:
                              parentId == null ? null : parentAuthors[parentId],
                          onReply: () => _reply(comment),
                        );
                      }),
                  ],
                ),
              ),
              if (isPostHidden)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 18),
                  child: Text(
                    'Bài đánh giá đã bị tắt nên không thể bình luận thêm.',
                    style: TextStyle(color: Color(0xFF77736D)),
                  ),
                )
              else
                _CommentComposer(
                  controller: _replyController,
                  replyingTo: _replyingTo,
                  sending: _sending,
                  onCancelReply: () => setState(() => _replyingTo = null),
                  onSend: _sendComment,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.onReply,
    this.parentAuthor,
  });
  final Map<String, dynamic> comment;
  final String? parentAuthor;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final author = (comment['authorName'] ?? 'Thành viên').toString();
    return Padding(
      padding: EdgeInsets.only(left: parentAuthor == null ? 0 : 22, bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
        decoration: BoxDecoration(
            color: const Color(0xFFF8F6F1),
            borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(author,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(_relativeDate(comment['createdAt']),
                style: const TextStyle(color: Color(0xFF77736D), fontSize: 11)),
          ]),
          if (parentAuthor != null) ...[
            const SizedBox(height: 3),
            Text('Trả lời $parentAuthor',
                style: const TextStyle(
                    color: _green, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
          const SizedBox(height: 4),
          Text(
            comment['isHidden'] == true || comment['isHidden']?.toString() == '1'
                ? 'Bình luận này đã bị quản trị viên tắt.'
                : (comment['content'] ?? '').toString(),
            style: comment['isHidden'] == true || comment['isHidden']?.toString() == '1'
                ? const TextStyle(color: Color(0xFF77736D), fontStyle: FontStyle.italic)
                : null,
          ),
          if (comment['isHidden'] != true && comment['isHidden']?.toString() != '1')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onReply,
                icon: const Icon(Icons.reply_rounded, size: 17),
                label: const Text('Trả lời'),
                style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: _green),
              ),
            ),
        ]),
      ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.replyingTo,
    required this.sending,
    required this.onCancelReply,
    required this.onSend,
  });
  final TextEditingController controller;
  final Map<String, dynamic>? replyingTo;
  final bool sending;
  final VoidCallback onCancelReply;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final replyName = (replyingTo?['authorName'] ?? '').toString();
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: const Border(top: BorderSide(color: _border)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (replyingTo != null)
            Row(children: [
              Expanded(
                  child: Text('Đang trả lời $replyName',
                      style: const TextStyle(color: _green, fontSize: 13))),
              IconButton(
                  onPressed: onCancelReply,
                  icon: const Icon(Icons.close, size: 18),
                  visualDensity: VisualDensity.compact),
            ]),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                decoration: InputDecoration(
                  hintText: replyingTo == null
                      ? 'Viết bình luận...'
                      : 'Trả lời $replyName...',
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: _border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: _border)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: sending ? null : onSend,
              tooltip: AppTranslations.translate('Gửi bình luận'),
              style: IconButton.styleFrom(
                  backgroundColor: _green, foregroundColor: Colors.white),
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
            ),
          ]),
        ]),
      ),
    );
  }
}

class CommunityReviewScreen extends StatefulWidget {
  const CommunityReviewScreen({super.key});

  @override
  State<CommunityReviewScreen> createState() => _CommunityReviewScreenState();
}

class _CommunityReviewScreenState extends State<CommunityReviewScreen> with AppLocaleAwareState<CommunityReviewScreen> {
  final _comment = TextEditingController();
  final _api = AuthApiService();
  int _rating = 4;
  String? _selectedReviewTargetKey;
  String _imagePath = '';
  bool _isSubmitting = false;
  bool _isUploadingImage = false;

  String get _displayName {
    final fullName = userSession.fullName?.trim() ?? '';
    if (fullName.isNotEmpty) return fullName;
    final username = userSession.username?.trim() ?? '';
    if (username.isNotEmpty) return username;
    return userSession.email?.split('@').first ?? 'Khách';
  }

  @override
  void dispose() {
    _comment.dispose();
    _api.close();
    super.dispose();
  }

  Future<void> _chooseImage() async {
    if (_isUploadingImage) return;
    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _isUploadingImage = true);
      final path = await UploadService().uploadImage(
        bytes: bytes,
        fileName: file.name,
        folder: 'community',
      );
      if (mounted) setState(() => _imagePath = path);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không tải được ảnh: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _submit() async {
    final message = _comment.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bạn hãy nhập nhận xét trước khi gửi.')));
      return;
    }

    final reviewTargets = favoritesStore.entries
        .where((entry) =>
            entry.kind == FavoriteKind.food ||
            entry.kind == FavoriteKind.place ||
            entry.kind == FavoriteKind.restaurant)
        .toList();
    if (reviewTargets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Bạn cần lưu món ăn, danh lam hoặc quán ăn trước khi gửi đánh giá.'),
      ));
      return;
    }

    final target = reviewTargets.firstWhere(
      (entry) => entry.key == _selectedReviewTargetKey,
      orElse: () => reviewTargets.first,
    );
    final reviewPlaceId = switch (target.kind) {
      FavoriteKind.place => target.id,
      FavoriteKind.food => 'food:${target.id}',
      FavoriteKind.restaurant => 'restaurant:${target.id}',
      FavoriteKind.itinerary => throw StateError(
          'Lịch trình không thể được đánh giá như một địa điểm.'),
    };
    final token = userSession.token;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Vui lòng đăng nhập lại để gửi đánh giá.')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _api.createCommunityPost(
        token: token,
        placeId: reviewPlaceId,
        placeName: target.title,
        rating: _rating,
        content: message,
        imageUrl: _imagePath,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on AuthApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể đăng đánh giá lúc này.')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = _displayName.isEmpty
        ? 'A'
        : String.fromCharCode(_displayName.runes.first).toUpperCase();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Viết đánh giá / bình luận'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
              children: [
                Row(children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _green,
                    child: Text(initial,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Đăng nhập với tên $_displayName')),
                ]),
                const SizedBox(height: 18),
                const Text('Chọn món ăn, danh lam hoặc quán đã lưu',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: favoritesStore,
                  builder: (context, _) {
                    final targets = favoritesStore.entries
                        .where((entry) =>
                            entry.kind == FavoriteKind.food ||
                            entry.kind == FavoriteKind.place ||
                            entry.kind == FavoriteKind.restaurant)
                        .toList();
                    final selected = targets.any(
                            (entry) => entry.key == _selectedReviewTargetKey)
                        ? _selectedReviewTargetKey
                        : targets.isEmpty
                            ? null
                            : targets.first.key;
                    if (targets.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _border)),
                        child: const Text(
                            'Bạn chưa lưu món ăn, danh lam hoặc quán ăn nào. Hãy lưu mục muốn đánh giá trước.',
                            style: TextStyle(color: Color(0xFF77736D))),
                      );
                    }
                    return DropdownButtonFormField<String>(
                      value: selected,
                      isExpanded: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.place_outlined),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: _border)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: _border)),
                      ),
                      items: targets
                          .map((entry) => DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(
                                    '${entry.kind.label} · ${entry.title}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (key) =>
                          setState(() => _selectedReviewTargetKey = key),
                    );
                  },
                ),
                const SizedBox(height: 18),
                Row(
                    children: List.generate(
                        5,
                        (index) => IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  setState(() => _rating = index + 1),
                              icon: Icon(
                                  index < _rating
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: const Color(0xFFE5AA25),
                                  size: 34),
                            ))),
                const SizedBox(height: 12),
                const Text('Nhận xét',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextField(
                  controller: _comment,
                  maxLength: 2000,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: AppTranslations.translate('Chia sẻ trải nghiệm của bạn...'),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _border)),
                  ),
                ),
                const SizedBox(height: 8),
                if (_imagePath.isNotEmpty)
                  Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AppImage(
                          source: _imagePath,
                          width: double.infinity,
                          height: 190,
                          fallbackIcon: Icons.image_outlined),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filled(
                        onPressed: () => setState(() => _imagePath = ''),
                        icon: const Icon(Icons.close),
                        style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white),
                      ),
                    ),
                  ])
                else
                  OutlinedButton.icon(
                    onPressed: _isUploadingImage ? null : _chooseImage,
                    icon: _isUploadingImage
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                        _isUploadingImage ? 'Đang tải ảnh lên...' : 'Thêm ảnh'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _green,
                      side: const BorderSide(color: _border),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                    ),
                  ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed:
                        _isSubmitting || _isUploadingImage ? null : _submit,
                    style: FilledButton.styleFrom(
                        backgroundColor: _red,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder()),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Đăng đánh giá',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Bài đánh giá sẽ xuất hiện trong Góc chia sẻ và được lưu vào hồ sơ của bạn.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF77736D), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
