class MimeUtils {
  static String getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png':  return 'image/png';
      case 'gif':  return 'image/gif';
      case 'mp4':  return 'video/mp4';
      case 'mp3':  return 'audio/mpeg';
      case 'm4a':  return 'audio/mp4';
      case 'pdf':  return 'application/pdf';
      case 'zip':  return 'application/zip';
      case 'fb2':  return 'application/fb2';
      default:     return 'application/octet-stream';
    }
  }
}