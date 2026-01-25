/****************************************************************************
 * OpenRCT2Shim - C interface for Swift interoperability
 * 
 * This file is intentionally minimal. All implementation lives in
 * VisionOSUiContext.cpp which has access to the full C++ type definitions.
 ****************************************************************************/

// The C shim functions are implemented directly in VisionOSUiContext.cpp
// to avoid incomplete type issues when the heavy OpenRCT2 headers are
// included. This file exists only to satisfy any build system dependencies.
