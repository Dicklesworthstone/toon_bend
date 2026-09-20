// Stdin.open, the JS side: Base's File is the descriptor number here (effs/file_open.js answers
// io_done(fd)), and File.read_bytes reads it through libc's read: descriptor 0 itself is the File.
function stdin_open() {
  return io_done(0);
}
