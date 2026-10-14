# libmgcalls: tgcalls and our C API in one dylib, linked against tg_owt and
# the codecs built by build.sh. Adapted from tdesktop's
# Telegram/cmake/lib_tgcalls.cmake and cmake_helpers/external/webrtc.
#
# Configure it through build.sh; it expects the paths below.

cmake_minimum_required(VERSION 3.21)
project(mgcalls LANGUAGES C CXX OBJC OBJCXX)

if (NOT APPLE)
    message(FATAL_ERROR "libmgcalls is built for macOS only for now.")
endif()

set(MGCALLS_TGCALLS_DIR "" CACHE PATH "tgcalls checkout")
set(MGCALLS_TG_OWT_DIR "" CACHE PATH "tg_owt checkout with out/libtg_owt.a")
set(MGCALLS_DEPS_PREFIX "" CACHE PATH "Prefix with the static codecs and OpenSSL")
foreach (var MGCALLS_TGCALLS_DIR MGCALLS_TG_OWT_DIR MGCALLS_DEPS_PREFIX)
    if ("${${var}}" STREQUAL "")
        message(FATAL_ERROR "${var} is not set.")
    endif()
endforeach()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_C_VISIBILITY_PRESET hidden)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_OBJC_VISIBILITY_PRESET hidden)
set(CMAKE_OBJCXX_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)

set(tgcalls_loc ${MGCALLS_TGCALLS_DIR}/tgcalls)
set(webrtc_loc ${MGCALLS_TG_OWT_DIR}/src)
set(deps ${MGCALLS_DEPS_PREFIX})

# The sources tdesktop compiles on macOS, minus Android, the Qt-based
# tdesktop platform and the Metal views (we render through Flutter).
set(tgcalls_sources
    Instance.cpp
    AudioDeviceHelper.cpp
    ChannelManager.cpp
    CodecSelectHelper.cpp
    CryptoHelper.cpp
    EncryptedConnection.cpp
    FakeAudioDeviceModule.cpp
    FieldTrialsConfig.cpp
    InstanceImpl.cpp
    LogSinkImpl.cpp
    Manager.cpp
    MediaManager.cpp
    Message.cpp
    NetworkManager.cpp
    SctpDataChannelProviderInterfaceImpl.cpp
    StaticThreads.cpp
    TurnCustomizerImpl.cpp
    VideoCaptureInterface.cpp
    VideoCaptureInterfaceImpl.cpp

    utils/gzip.cpp

    v2/ContentNegotiation.cpp
    v2/CustomDcSctpSocket.cpp
    v2/DirectNetworkingImpl.cpp
    v2/ExternalSignalingConnection.cpp
    v2/InstanceV2ReferenceImpl.cpp
    v2/InstanceV2Impl.cpp
    v2/MtProtoIceTransport.cpp
    v2/NativeNetworkingImpl.cpp
    v2/RawTcpSocket.cpp
    v2/ReflectorPort.cpp
    v2/ReflectorRelayPortFactory.cpp
    v2/Signaling.cpp
    v2/SignalingConnection.cpp
    v2/SignalingEncryption.cpp
    v2/SignalingSctpConnection.cpp

    desktop_capturer/DesktopCaptureSource.cpp
    desktop_capturer/DesktopCaptureSourceHelper.cpp
    desktop_capturer/DesktopCaptureSourceManager.cpp

    group/AVIOContextImpl.cpp
    group/AudioStreamingPart.cpp
    group/AudioStreamingPartInternal.cpp
    group/AudioStreamingPartPersistentDecoder.cpp
    group/GroupInstanceCustomImpl.cpp
    group/GroupJoinPayloadInternal.cpp
    group/GroupNetworkManager.cpp
    group/StreamingAudioRenderer.cpp
    group/StreamingMediaContext.cpp
    group/VideoStreamingPart.cpp

    platform/darwin/CustomSimulcastEncoderAdapter.cpp
    platform/darwin/DarwinFFMpeg.mm
    platform/darwin/DarwinInterface.mm
    platform/darwin/DarwinVideoSource.mm
    platform/darwin/DesktopSharingCapturer.mm
    platform/darwin/ExtractCVPixelBuffer.mm
    platform/darwin/h265_nalu_rewriter.cc
    platform/darwin/objc_video_encoder_factory.mm
    platform/darwin/objc_video_decoder_factory.mm
    platform/darwin/RTCCodecSpecificInfoH265.mm
    platform/darwin/RTCH265ProfileLevelId.mm
    platform/darwin/TGCMIOCapturer.m
    platform/darwin/TGCMIODevice.mm
    platform/darwin/TGRTCCVPixelBuffer.mm
    platform/darwin/TGRTCDefaultVideoDecoderFactory.mm
    platform/darwin/TGRTCDefaultVideoEncoderFactory.mm
    platform/darwin/TGRTCVideoDecoderH264.mm
    platform/darwin/TGRTCVideoDecoderH265.mm
    platform/darwin/TGRTCVideoEncoderH264.mm
    platform/darwin/TGRTCVideoEncoderH265.mm
    platform/darwin/VideoCameraCapturerMac.mm
    platform/darwin/VideoCapturerInterfaceImpl.mm
    platform/darwin/VideoCMIOCapture.mm

    third-party/json11.cpp
)
list(TRANSFORM tgcalls_sources PREPEND ${tgcalls_loc}/)

add_library(mgcalls SHARED
    src/mg_calls.cpp
    ${tgcalls_sources}
)

set_target_properties(mgcalls PROPERTIES
    OUTPUT_NAME mgcalls
    INSTALL_NAME_DIR "@rpath"
    BUILD_WITH_INSTALL_NAME_DIR ON
)

target_include_directories(mgcalls
PRIVATE
    include
    ${MGCALLS_TGCALLS_DIR}
    ${tgcalls_loc}
)

target_include_directories(mgcalls SYSTEM
PRIVATE
    ${webrtc_loc}
    ${webrtc_loc}/third_party/abseil-cpp
    ${webrtc_loc}/third_party/libyuv/include
    ${webrtc_loc}/sdk/objc
    ${webrtc_loc}/sdk/objc/base
    ${webrtc_loc}/sdk/objc/components/video_codec
    ${deps}/include
)

target_compile_definitions(mgcalls
PRIVATE
    MGCALLS_BUILD
    TGCALLS_USE_STD_OPTIONAL
    WEBRTC_APP_TDESKTOP
    RTC_ENABLE_H265
    RTC_ENABLE_VP9
    WEBRTC_ENABLE_PROTOBUF=0
    WEBRTC_INCLUDE_INTERNAL_AUDIO_DEVICE
    HAVE_SCTP
    WEBRTC_USE_H264
    WEBRTC_USE_BUILTIN_ISAC_FLOAT
    WEBRTC_LIBRARY_IMPL
    WEBRTC_NON_STATIC_TRACE_EVENT_HANDLERS=1
    WEBRTC_HAVE_DCSCTP
    WEBRTC_HAVE_SCTP
    ABSL_ALLOCATOR_NOTHROW=1
    WEBRTC_MAC
    WEBRTC_POSIX
)

target_compile_options(mgcalls
PRIVATE
    $<$<COMPILE_LANGUAGE:OBJC,OBJCXX>:-fobjc-arc>
    $<$<COMPILE_LANGUAGE:OBJC,OBJCXX>:-fobjc-weak>
    -Wno-deprecated-volatile
    -Wno-ambiguous-reversed-operator
    -Wno-deprecated-declarations
    -Wno-unqualified-std-cast-call
    -Wno-unused-function
    -Wno-unused-variable
    -Wno-unused-parameter
    -Wno-missing-field-initializers
    -Wno-shorten-64-to-32
    "-Wno-error=#warnings"
)

target_link_libraries(mgcalls
PRIVATE
    ${MGCALLS_TG_OWT_DIR}/out/libtg_owt.a
    ${deps}/lib/libavformat.a
    ${deps}/lib/libavcodec.a
    ${deps}/lib/libswresample.a
    ${deps}/lib/libswscale.a
    ${deps}/lib/libavutil.a
    ${deps}/lib/libopenh264.a
    ${deps}/lib/libvpx.a
    ${deps}/lib/libopus.a
    ${deps}/lib/libjpeg.a
    ${deps}/lib/librnnoise.a
    ${deps}/lib/libssl.a
    ${deps}/lib/libcrypto.a
    z
    c++
    resolv
    "-framework AppKit"
    "-framework AudioToolbox"
    "-framework AVFoundation"
    "-framework CoreAudio"
    "-framework CoreFoundation"
    "-framework CoreGraphics"
    "-framework CoreMedia"
    "-framework CoreMediaIO"
    "-framework CoreServices"
    "-framework CoreVideo"
    "-framework Foundation"
    "-framework IOKit"
    "-framework IOSurface"
    "-framework Metal"
    "-framework QuartzCore"
    "-framework Security"
    "-framework SystemConfiguration"
    "-framework VideoToolbox"
    "-ObjC"
)

# Export only the C API. OpenSSL, abseil and WebRTC stay private, so they
# cannot clash with the OpenSSL inside libtdjson in the same process.
target_link_options(mgcalls
PRIVATE
    "LINKER:-exported_symbols_list,${CMAKE_CURRENT_SOURCE_DIR}/exports.txt"
    "LINKER:-dead_strip"
)
set_property(TARGET mgcalls APPEND PROPERTY
    LINK_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/exports.txt)
