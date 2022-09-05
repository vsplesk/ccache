// Copyright (C) 2021-2022 Joel Rosdahl and other contributors
//
// See doc/AUTHORS.adoc for a complete list of contributors.
//
// This program is free software; you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation; either version 3 of the License, or (at your option)
// any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
// more details.
//
// You should have received a copy of the GNU General Public License along with
// this program; if not, write to the Free Software Foundation, Inc., 51
// Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA

#pragma once

#include <third_party/nonstd/optional.hpp>

#include <ctime>
#include <string>

namespace util {

// --- Interface ---

void create_cachedir_tag(const std::string& dir);

// Set atime/mtime of `path`. If `mtime` is nonstd::nullopt, set to the current
// time. If `atime` is nonstd::nullopt, set to what `mtime` specifies.
void set_timestamps(const std::string& path,
                    nonstd::optional<timespec> mtime = nonstd::nullopt,
                    nonstd::optional<timespec> atime = nonstd::nullopt);

} // namespace util
