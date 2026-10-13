#include <linux/atomic.h>
#include <linux/jump_label.h>

/*
 * Legacy init.rc-read hook key referenced by the base tree's
 * fs/read_write.c (susfs inline hook style).
 *
 * BakaSU in MANUAL_HOOK mode does not define this symbol: it uses its
 * own ksu_init_rc_hook key and an LSM based AUTO_INITRC hook instead.
 * Provide the legacy key here in permanently disabled state so the
 * dormant call site in read_write.c links and never fires.
 */
struct static_key_true ksu_is_init_rc_hook_enabled = {
	.key = {
		.enabled = ATOMIC_INIT(0),
	},
};
