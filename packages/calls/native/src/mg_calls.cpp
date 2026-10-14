#include "mg_calls.h"

#include <algorithm>
#include <cstdlib>
#include <string>
#include <vector>

#include "Instance.h"
#include "InstanceImpl.h"
#include "v2/InstanceV2Impl.h"
#include "v2/InstanceV2ReferenceImpl.h"

namespace {

// The same set tdesktop registers (calls_call.cpp). Newer engines such as
// InstanceV2CompatImpl stay off until tdesktop ships them.
void RegisterImplementations() {
  static const bool registered = [] {
    tgcalls::Register<tgcalls::InstanceImpl>();
    tgcalls::Register<tgcalls::InstanceV2Impl>();
    tgcalls::Register<tgcalls::InstanceV2ReferenceImpl>();
    return true;
  }();
  (void)registered;
}

std::vector<int> ParseVersion(const std::string &version) {
  std::vector<int> parts;
  size_t start = 0;
  while (start <= version.size()) {
    const auto end = std::min(version.find('.', start), version.size());
    parts.push_back(std::atoi(version.substr(start, end - start).c_str()));
    start = end + 1;
  }
  return parts;
}

std::string VersionsJson() {
  RegisterImplementations();
  auto versions = tgcalls::Meta::Versions();
  std::sort(versions.begin(), versions.end(),
            [](const std::string &a, const std::string &b) {
              return ParseVersion(a) > ParseVersion(b);
            });
  std::string json = "[";
  for (size_t i = 0; i < versions.size(); ++i) {
    if (i > 0) json += ',';
    json += '"' + versions[i] + '"';
  }
  json += ']';
  return json;
}

} // namespace

extern "C" {

int32_t mg_calls_api_version(void) {
  return MG_CALLS_API_VERSION;
}

const char *mg_calls_versions_json(void) {
  static const std::string json = VersionsJson();
  return json.c_str();
}

int32_t mg_calls_max_layer(void) {
  RegisterImplementations();
  return tgcalls::Meta::MaxLayer();
}

} // extern "C"
