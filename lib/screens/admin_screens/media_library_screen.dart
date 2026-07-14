import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class MediaLibraryScreen extends StatefulWidget {
  const MediaLibraryScreen({super.key});

  @override
  State<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends State<MediaLibraryScreen> {
  final Color _primaryDark = const Color(0xFF1A237E); // Xanh đen chủ đạo
  final Color _bgLight = Colors.white;

  int _selectedFilterIndex = 0;
  final List<String> _filters = ['Tất cả', 'Thư mục', 'Gần đây'];

  bool _isSelectionMode = false;
  final Set<int> _selectedImageIndices = {};

  List<Map<String, String>> _images = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImagesFromFirebase();
  }

  // --- HÀM 1: LẤY DANH SÁCH ẢNH TỪ FIREBASE ---
  Future<void> _loadImagesFromFirebase() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final ListResult result = await FirebaseStorage.instance
          .ref('QuestionImages')
          .listAll();
      final List<Map<String, String>> fetchedImages = [];

      for (var item in result.items) {
        final url = await item.getDownloadURL();
        fetchedImages.add({
          'name': item.name,
          'url': url,
          'fullPath': item.fullPath,
        });
      }

      if (mounted) {
        setState(() {
          _images = fetchedImages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải ảnh: $e')));
      }
    }
  }

  // --- HÀM 2: THÊM ẢNH MỚI (UPLOAD) ---
  Future<void> _uploadNewImages() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true, // Cho phép chọn nhiều ảnh cùng lúc
        withData: true,
      );

      if (result == null) return;

      // Hiển thị vòng tải loading
      setState(() => _isLoading = true);

      for (var file in result.files) {
        String fileName = file.name;

        Reference ref = FirebaseStorage.instance.ref().child(
          'QuestionImages/$fileName',
        );

        // Kiểm tra xem trùng tên không
        try {
          await ref.getDownloadURL();
          // Nếu lấy được URL nghĩa là đã trùng tên -> Bỏ qua hoặc báo lỗi công khai
          continue;
        } catch (_) {
          // Báo lỗi nghĩa là file chưa tồn tại -> An toàn để upload
        }
        if (kIsWeb) {
          await ref.putData(file.bytes!); // Web
        } else {
          File imageFile = File(file.path!);
          await ref.putFile(imageFile); // App
        }
      }

      // Load lại thư viện sau khi up xong
      _loadImagesFromFirebase();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã import ảnh mới thành công!')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải lên ảnh: $e')));
      }
    }
  }

  // --- HÀM 3: SỬA TÊN ẢNH (RENAME) ---
  Future<void> _renameImage(int index, String newNameRaw) async {
    if (newNameRaw.trim().isEmpty) return;

    String oldName = _images[index]['name']!;
    String oldPath = _images[index]['fullPath']!;

    // Tách lấy đuôi file gốc (vd: .jpg hoặc .png) để tự động điền nếu admin quên gõ
    String ext = oldName.split('.').last;
    String newName = newNameRaw.contains('.')
        ? newNameRaw.trim()
        : '${newNameRaw.trim()}.$ext';

    if (oldName == newName) return; // Không đổi gì thì thoát

    setState(() => _isLoading = true);

    try {
      final oldRef = FirebaseStorage.instance.ref(oldPath);
      final newRef = FirebaseStorage.instance.ref().child(
        'QuestionImages/$newName',
      );

      // 1. Kiểm tra xem tên mới đã bị trùng với ai khác chưa
      try {
        await newRef.getDownloadURL();
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lỗi: Tên ảnh mới này đã tồn tại trên hệ thống!'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      } catch (_) {}

      // 2. Tiến hành copy: Lấy mảng Byte dữ liệu từ file cũ
      final data = await oldRef.getData();
      if (data != null) {
        // 3. Đẩy mảng Byte đó lên đường dẫn tên mới
        await newRef.putData(data);
        // 4. Xóa file tên cũ đi
        await oldRef.delete();

        _loadImagesFromFirebase(); // Làm mới giao diện
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã đổi tên ảnh thành công!')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi đổi tên: $e')));
      }
    }
  }

  // --- HÀM 4: XÓA NHIỀU ẢNH (BATCH DELETE) ---
  Future<void> _deleteSelectedImages() async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đang xóa ảnh...')));

    try {
      for (int index in _selectedImageIndices) {
        String path = _images[index]['fullPath']!;
        await FirebaseStorage.instance.ref(path).delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã xóa thành công ${_selectedImageIndices.length} ảnh!',
            ),
          ),
        );
        setState(() {
          _isSelectionMode = false;
          _selectedImageIndices.clear();
        });
        _loadImagesFromFirebase();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi xóa ảnh: $e')));
      }
    }
  }

  // --- MENU ĐIỀU HƯỚNG TÙY CHỌN CHO TỪNG ẢNH ---
  void _showImageOptions(int index) {
    String currentName = _images[index]['name']!;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  currentName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.visibility_outlined,
                  color: Colors.blue,
                ),
                title: const Text('Xem ảnh phóng to'),
                onTap: () {
                  Navigator.pop(context);
                  _viewFullImage(_images[index]['url']!, currentName);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.orange),
                title: const Text('Sửa tên ảnh'),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameDialog(index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Xóa ảnh này',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  setState(() {
                    _selectedImageIndices.clear();
                    _selectedImageIndices.add(index);
                  });
                  await _deleteSelectedImages();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- POPUP NHẬP TÊN MỚI ---
  void _showRenameDialog(int index) {
    final TextEditingController renameCtrl = TextEditingController(
      text: _images[index]['name'],
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Sửa tên ảnh',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: renameCtrl,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Tên file mới',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryDark),
            onPressed: () {
              Navigator.pop(context);
              _renameImage(index, renameCtrl.text);
            },
            child: const Text('Đổi tên', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- POPUP XEM TOÀN MÀN HÌNH ---
  void _viewFullImage(String url, String name) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedImageIndices.clear();
      }
    });
  }

  void _toggleImageSelection(int index) {
    setState(() {
      if (_selectedImageIndices.contains(index)) {
        _selectedImageIndices.remove(index);
        if (_selectedImageIndices.isEmpty) _isSelectionMode = false;
      } else {
        _selectedImageIndices.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Thư viện hình ảnh',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black87),
            onPressed: () {},
          ),
          if (_images.isNotEmpty)
            TextButton(
              onPressed: _toggleSelectionMode,
              child: Text(
                _isSelectionMode ? 'Hủy' : 'Chọn',
                style: TextStyle(
                  color: _isSelectionMode ? Colors.red : _primaryDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),

      // NÚT THÊM ẢNH MỚI (FAB) - Chỉ hiện khi không ở chế độ chọn nhiều để xóa
      floatingActionButton: !_isSelectionMode
          ? FloatingActionButton(
              backgroundColor: _primaryDark,
              foregroundColor: Colors.white,
              onPressed: _uploadNewImages, // Kích hoạt chọn và up ảnh luôn
              child: const Icon(Icons.add_photo_alternate_outlined),
            )
          : null,

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- FILTER TABS ---
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(left: 16, bottom: 12, top: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_filters.length, (index) {
                  bool isSelected = _selectedFilterIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFilterIndex = index),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? _primaryDark : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? _primaryDark
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        _filters[index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          // --- GRIDVIEW HÌNH ẢNH ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _images.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Thư viện đang trống.\nNhấn nút "+" để thêm ảnh mới.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                          childAspectRatio: 1,
                        ),
                    itemCount: _images.length,
                    itemBuilder: (context, index) {
                      bool isSelected = _selectedImageIndices.contains(index);

                      return GestureDetector(
                        onLongPress: () {
                          if (!_isSelectionMode) {
                            setState(() {
                              _isSelectionMode = true;
                              _selectedImageIndices.add(index);
                            });
                          }
                        },
                        onTap: () {
                          if (_isSelectionMode) {
                            _toggleImageSelection(index);
                          } else {
                            _showImageOptions(
                              index,
                            ); // Mở Menu Lựa chọn: Xem / Sửa / Xóa
                          }
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              _images[index]['url']!,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      color: Colors.grey.shade100,
                                    );
                                  },
                            ),
                            if (isSelected)
                              Container(
                                color: Colors.black.withValues(alpha: 0.3),
                              ),
                            if (_isSelectionMode)
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.blue.shade600
                                        : Colors.black.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          size: 14,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),

      // --- THANH CÔNG CỤ DƯỚI CÙNG (HIỆN KHI CHỌN NHIỀU FILE ĐỂ XÓA) ---
      bottomNavigationBar: _selectedImageIndices.isNotEmpty
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _deleteSelectedImages,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text(
                          'Xóa',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: _primaryDark,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {},
                        icon: const Icon(Icons.drive_file_move_outline),
                        label: const Text(
                          'Di chuyển',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
