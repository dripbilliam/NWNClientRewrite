#include "drive_clear_kernel.hpp"
bool bind_drive_clear_math();
Var configure_drive_batch(drive_clear_kernel::Batch&,const Var&);
Var query_drive_batch(const drive_clear_kernel::Batch&,const Var&,bool);
