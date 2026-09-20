// Stdin.open, the C side: a Base File for descriptor 0 itself (a duplicate: the same open file
// description, so the offset, the O_NONBLOCK flag and the kind of object -- pipe, file, socket,
// terminal -- are the caller's; closing the File leaves descriptor 0 alone).
Term stdin_open_run(Env e, Term* f, IoWork* w) {
  int fd = dup(0);
  return fd < 0 ? io_fail(e, (u32)errno, NULL) : io_done(e, io_hand(fd));
}

static void __attribute__((constructor)) stdin_open_use(void) {
  io_eff(CID_STDIN_OPEN, stdin_open_run, 0);
}
