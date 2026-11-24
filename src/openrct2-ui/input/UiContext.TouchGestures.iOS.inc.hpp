/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/
// Included inside UiContext's private section. Keeps TestFlight touch behaviour
// identical while moving the iOS gesture classifier out of UiContext.cpp.

#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_IOS
    ScreenCoordsXY GetTouchPosition(const SDL_TouchFingerEvent& event) const
    {
        return { static_cast<int32_t>(event.x * _width), static_cast<int32_t>(event.y * _height) };
    }

    static int64_t GetTouchDistanceSquared(const ScreenCoordsXY& first, const ScreenCoordsXY& second)
    {
        const int64_t deltaX = first.x - second.x;
        const int64_t deltaY = first.y - second.y;
        return deltaX * deltaX + deltaY * deltaY;
    }

    ScreenCoordsXY GetTouchCentroid() const
    {
        return { (_primaryTouch.position.x + _secondaryTouch.position.x) / 2,
                 (_primaryTouch.position.y + _secondaryTouch.position.y) / 2 };
    }

    float GetTouchSpan() const
    {
        const auto deltaX = static_cast<float>(_primaryTouch.position.x - _secondaryTouch.position.x);
        const auto deltaY = static_cast<float>(_primaryTouch.position.y - _secondaryTouch.position.y);
        return std::hypot(deltaX, deltaY);
    }

    float GetTouchAngle() const
    {
        const auto deltaX = static_cast<float>(_secondaryTouch.position.x - _primaryTouch.position.x);
        const auto deltaY = static_cast<float>(_secondaryTouch.position.y - _primaryTouch.position.y);
        return std::atan2(deltaY, deltaX);
    }

    static float NormaliseTouchAngle(float angle)
    {
        constexpr float pi = 3.14159265f;
        constexpr float twoPi = 2.0f * pi;
        while (angle > pi)
        {
            angle -= twoPi;
        }
        while (angle < -pi)
        {
            angle += twoPi;
        }
        return angle;
    }

    bool IsDeliberatePinch(float span, float centroidDistance) const
    {
        const auto spanDistance = std::abs(span - _touchGestureStartSpan);
        const auto pinchThreshold = std::max(kTouchPinchThreshold, _touchGestureStartSpan * kTouchPinchSpanRatio);
        return spanDistance >= pinchThreshold && spanDistance >= centroidDistance * kTouchPinchDominance;
    }

    bool CanRotateTouchConstruction() const
    {
        if (!gInputFlags.has(InputFlag::toolActive))
        {
            return false;
        }

        switch (gCurrentToolWidget.windowClassification)
        {
            case WindowClass::scenery:
            case WindowClass::rideConstruction:
            case WindowClass::trackDesignPlace:
                return true;
            default:
                return false;
        }
    }

    bool IsDeliberateRotation(float angle, float span, float centroidDistance) const
    {
        if (!CanRotateTouchConstruction())
        {
            return false;
        }

        const auto angleDistance = std::abs(NormaliseTouchAngle(angle - _touchGestureStartAngle));
        const auto rotationDistance = angleDistance * std::max(1.0f, _touchGestureStartSpan * 0.5f);
        const auto spanDistance = std::abs(span - _touchGestureStartSpan);
        const auto pinchThreshold = std::max(kTouchPinchThreshold, _touchGestureStartSpan * kTouchPinchSpanRatio);
        return angleDistance >= kTouchRotationThreshold && rotationDistance >= centroidDistance * kTouchRotationDominance
            && spanDistance < pinchThreshold;
    }

    void RotateTouchConstruction(bool clockwise)
    {
        auto* shortcut = _shortcutManager.getShortcut(ShortcutId::kInterfaceRotateConstruction);
        if (shortcut == nullptr)
        {
            return;
        }

        const int32_t rotations = clockwise ? 1 : 3;
        for (int32_t i = 0; i < rotations; i++)
        {
            shortcut->action();
        }
    }

    void BeginTouchRotation(float angle)
    {
        const auto direction = NormaliseTouchAngle(angle - _touchGestureStartAngle);
        _touchGestureMode = TouchGestureMode::multiRotate;
        _touchLastAngle = angle;
        _touchRotationAccumulator = 0;
        RotateTouchConstruction(direction > 0);
    }

    void ContinueTouchRotation(float angle)
    {
        _touchRotationAccumulator += NormaliseTouchAngle(angle - _touchLastAngle);
        _touchLastAngle = angle;
        while (std::abs(_touchRotationAccumulator) >= kTouchRotationStep)
        {
            const bool clockwise = _touchRotationAccumulator > 0;
            RotateTouchConstruction(clockwise);
            _touchRotationAccumulator += clockwise ? -kTouchRotationStep : kTouchRotationStep;
        }
    }

    bool CanPaintWithTouch(const ScreenCoordsXY& position) const
    {
        if (!gInputFlags.has(InputFlag::toolActive) || ViewportFindFromPoint(position) == nullptr)
        {
            return false;
        }

        switch (gCurrentToolWidget.windowClassification)
        {
            case WindowClass::footpath:
            case WindowClass::land:
            case WindowClass::water:
            case WindowClass::clearScenery:
                return true;
            default:
                return false;
        }
    }

    bool CanUseTouchSecondaryAction(const ScreenCoordsXY& position) const
    {
        return gInputFlags.has(InputFlag::toolActive) && gInputFlags.has(InputFlag::allowRightMouseRemoval)
            && ViewportInteractionRightOver(position);
    }

    bool CanEraseFootpathWithTouch(const ScreenCoordsXY& position) const
    {
        return gCurrentToolWidget.windowClassification == WindowClass::footpath && CanUseTouchSecondaryAction(position);
    }

    void FireTouchSecondaryAction(const ScreenCoordsXY& position)
    {
        _cursorState.position = position;
        _cursorState.touch = true;
        ViewportInteractionRightClick(position);
    }

    void StoreTouchPress(MouseState state, const ScreenCoordsXY& position)
    {
        StoreMouseInput(state, position);
        _cursorState.position = position;
        _cursorState.touch = true;

        if (state == MouseState::leftPress)
        {
            _cursorState.left = CURSOR_PRESSED;
            _cursorState.old = 1;
        }
        else if (state == MouseState::rightPress)
        {
            _cursorState.right = CURSOR_PRESSED;
            _cursorState.old = 2;
        }
    }

    void StoreTouchRelease(MouseState state, const ScreenCoordsXY& position)
    {
        StoreMouseInput(state, position);
        _cursorState.position = position;
        _cursorState.touch = true;

        if (state == MouseState::leftRelease)
        {
            _cursorState.left = CURSOR_RELEASED;
            _cursorState.old = 3;
        }
        else if (state == MouseState::rightRelease)
        {
            _cursorState.right = CURSOR_RELEASED;
            _cursorState.old = 4;
        }
    }

    void BeginTouchPan(const ScreenCoordsXY& origin)
    {
        StoreTouchPress(MouseState::rightPress, origin);
        _touchLastCentroid = origin;
        _touchPanCursorX = static_cast<float>(origin.x);
        _touchPanCursorY = static_cast<float>(origin.y);
    }

    void ContinueTouchPan(const ScreenCoordsXY& current)
    {
        const auto delta = current - _touchLastCentroid;
        _touchLastCentroid = current;
        _touchPanCursorX -= static_cast<float>(delta.x) * kTouchPanSensitivity;
        _touchPanCursorY -= static_cast<float>(delta.y) * kTouchPanSensitivity;
        _cursorState.position = { static_cast<int32_t>(std::lround(_touchPanCursorX)),
                                  static_cast<int32_t>(std::lround(_touchPanCursorY)) };
        _cursorState.touch = true;
    }

    void FireTouchTap(const ScreenCoordsXY& position)
    {
        StoreTouchPress(MouseState::leftPress, position);
        StoreTouchRelease(MouseState::leftRelease, position);
    }

    void FireTouchLongPress(const ScreenCoordsXY& position)
    {
        _lastTouchToolTapTimestamp = 0;
        StoreTouchPress(MouseState::rightPress, position);
        StoreTouchRelease(MouseState::rightRelease, position);
        _touchGestureMode = TouchGestureMode::longPressFired;
    }

    void HandleTouchTap(const SDL_TouchFingerEvent& event, const ScreenCoordsXY& position)
    {
        const bool isActiveToolViewport = gInputFlags.has(InputFlag::toolActive) && ViewportFindFromPoint(position) != nullptr;
        if (!isActiveToolViewport)
        {
            _lastTouchToolTapTimestamp = 0;
            FireTouchTap(position);
            return;
        }

        const int64_t tapDistanceSquared = kTouchToolTapDistance * kTouchToolTapDistance;
        const bool isDoubleTap = _lastTouchToolTapTimestamp != 0
            && event.timestamp - _lastTouchToolTapTimestamp < kTouchDoubleTimeout
            && GetTouchDistanceSquared(position, _lastTouchToolTap) <= tapDistanceSquared;
        if (isDoubleTap)
        {
            _lastTouchToolTapTimestamp = 0;
            FireTouchTap(position);
        }
        else
        {
            _lastTouchToolTap = position;
            _lastTouchToolTapTimestamp = event.timestamp;
            _cursorState.position = position;
        }
    }

    void AddTrackpadViewportWheel(int32_t delta)
    {
        if ((_trackpadViewportWheelAccumulator < 0 && delta > 0) || (_trackpadViewportWheelAccumulator > 0 && delta < 0))
        {
            _trackpadViewportWheelAccumulator = 0;
        }

        _trackpadViewportWheelAccumulator = std::clamp(
            _trackpadViewportWheelAccumulator + delta, -kTrackpadViewportWheelStep, kTrackpadViewportWheelStep);
        if (std::abs(_trackpadViewportWheelAccumulator) == kTrackpadViewportWheelStep)
        {
            _cursorState.wheel += _trackpadViewportWheelAccumulator > 0 ? 1 : -1;
            _trackpadViewportWheelAccumulator = 0;
        }
    }

    void ResetTouchGesture()
    {
        _primaryTouch = {};
        _secondaryTouch = {};
        _touchGestureMode = TouchGestureMode::none;
        _touchGestureStart = {};
        _touchLastCentroid = {};
        _touchPanCursorX = 0;
        _touchPanCursorY = 0;
        _touchGestureStartSpan = 0;
        _touchLastSpan = 0;
        _touchPinchAccumulator = 0;
        _touchGestureStartTimestamp = 0;
        _touchGestureStartAngle = 0;
        _touchLastAngle = 0;
        _touchRotationAccumulator = 0;
        _touchLastRemovePosition = {};
    }

    void HandleTouchDown(const SDL_TouchFingerEvent& event)
    {
        const auto position = GetTouchPosition(event);
        _cursorState.position = position;
        _cursorState.touch = true;

        if (!_primaryTouch.active)
        {
            _primaryTouch = { event.fingerId, position, true };
            _touchGestureMode = TouchGestureMode::singlePending;
            _touchGestureStart = position;
            _touchGestureStartTimestamp = event.timestamp;
            return;
        }

        if (_secondaryTouch.active || event.fingerId == _primaryTouch.id)
        {
            return;
        }

        if (_touchGestureMode == TouchGestureMode::singleDrag)
        {
            StoreTouchRelease(MouseState::leftRelease, _primaryTouch.position);
        }
        else if (_touchGestureMode == TouchGestureMode::singlePan)
        {
            StoreTouchRelease(MouseState::rightRelease, _cursorState.position);
        }

        _lastTouchToolTapTimestamp = 0;

        _secondaryTouch = { event.fingerId, position, true };
        _touchGestureMode = TouchGestureMode::multiPending;
        _touchGestureStart = GetTouchCentroid();
        _touchLastCentroid = _touchGestureStart;
        _touchPanCursorX = static_cast<float>(_touchGestureStart.x);
        _touchPanCursorY = static_cast<float>(_touchGestureStart.y);
        _touchGestureStartSpan = GetTouchSpan();
        _touchLastSpan = _touchGestureStartSpan;
        _touchGestureStartAngle = GetTouchAngle();
        _touchLastAngle = _touchGestureStartAngle;
        _touchPinchAccumulator = 0;
        _touchRotationAccumulator = 0;
        _touchLastRemovePosition = _touchGestureStart;
        _touchGestureStartTimestamp = event.timestamp;
        _cursorState.position = _touchGestureStart;
    }

    void HandleTouchMotion(const SDL_TouchFingerEvent& event)
    {
        const auto position = GetTouchPosition(event);
        if (_primaryTouch.active && event.fingerId == _primaryTouch.id)
        {
            _primaryTouch.position = position;
        }
        else if (_secondaryTouch.active && event.fingerId == _secondaryTouch.id)
        {
            _secondaryTouch.position = position;
        }
        else
        {
            return;
        }

        const int64_t dragThresholdSquared = kTouchDragThreshold * kTouchDragThreshold;
        if (_secondaryTouch.active)
        {
            const auto centroid = GetTouchCentroid();
            const auto span = GetTouchSpan();
            const auto angle = GetTouchAngle();
            const auto centroidDistance = std::sqrt(static_cast<float>(GetTouchDistanceSquared(centroid, _touchGestureStart)));

            if (_touchGestureMode == TouchGestureMode::multiRemove)
            {
                const int64_t removalThresholdSquared = kTouchRemovalDragThreshold * kTouchRemovalDragThreshold;
                if (GetTouchDistanceSquared(centroid, _touchLastRemovePosition) >= removalThresholdSquared)
                {
                    if (CanEraseFootpathWithTouch(centroid))
                    {
                        FireTouchSecondaryAction(centroid);
                    }
                    _touchLastRemovePosition = centroid;
                }
                _cursorState.position = centroid;
                return;
            }

            if (_touchGestureMode == TouchGestureMode::multiPending)
            {
                if (IsDeliberatePinch(span, centroidDistance))
                {
                    _touchGestureMode = TouchGestureMode::multiPinch;
                    _touchPinchAccumulator = span - _touchGestureStartSpan;
                    _touchLastSpan = span;
                }
                else if (IsDeliberateRotation(angle, span, centroidDistance))
                {
                    BeginTouchRotation(angle);
                }
                else
                {
                    int32_t panThreshold = kTouchPanStartThreshold;
                    if (CanRotateTouchConstruction())
                    {
                        panThreshold = kTouchConstructionPanStartThreshold;
                    }
                    else if (CanEraseFootpathWithTouch(_touchGestureStart))
                    {
                        panThreshold = kTouchRemovalPanStartThreshold;
                    }

                    if (centroidDistance >= panThreshold)
                    {
                        BeginTouchPan(_touchGestureStart);
                        _touchGestureMode = TouchGestureMode::multiPan;
                    }
                }
            }

            if (_touchGestureMode == TouchGestureMode::multiPan)
            {
                if (IsDeliberatePinch(span, centroidDistance))
                {
                    StoreTouchRelease(MouseState::rightRelease, _cursorState.position);
                    _touchGestureMode = TouchGestureMode::multiPinch;
                    _touchPinchAccumulator = span - _touchGestureStartSpan;
                    _touchLastSpan = span;
                    _cursorState.position = centroid;
                }
                else if (IsDeliberateRotation(angle, span, centroidDistance))
                {
                    StoreTouchRelease(MouseState::rightRelease, _cursorState.position);
                    BeginTouchRotation(angle);
                    _cursorState.position = centroid;
                }
                else
                {
                    ContinueTouchPan(centroid);
                }
            }

            if (_touchGestureMode == TouchGestureMode::multiPinch)
            {
                _touchPinchAccumulator += span - _touchLastSpan;
                _touchLastSpan = span;
                _cursorState.position = centroid;

                while (std::abs(_touchPinchAccumulator) >= kTouchZoomStep)
                {
                    const bool zoomIn = _touchPinchAccumulator > 0;
                    Windows::MainWindowZoom(zoomIn, true);
                    _touchPinchAccumulator += zoomIn ? -kTouchZoomStep : kTouchZoomStep;
                }
            }
            else if (_touchGestureMode == TouchGestureMode::multiRotate)
            {
                ContinueTouchRotation(angle);
                _cursorState.position = centroid;
            }
            else if (_touchGestureMode == TouchGestureMode::multiPending)
            {
                _cursorState.position = centroid;
            }
            return;
        }

        if (_touchGestureMode == TouchGestureMode::suppressed)
        {
            _cursorState.position = position;
            return;
        }

        if (_touchGestureMode == TouchGestureMode::singlePan)
        {
            ContinueTouchPan(position);
            return;
        }

        if (_touchGestureMode == TouchGestureMode::singlePending)
        {
            const int64_t distanceSquared = GetTouchDistanceSquared(position, _touchGestureStart);
            const bool onViewport = ViewportFindFromPoint(_touchGestureStart) != nullptr;
            if (onViewport)
            {
                if (gInputFlags.has(InputFlag::toolActive))
                {
                    if (distanceSquared >= dragThresholdSquared)
                    {
                        _lastTouchToolTapTimestamp = 0;
                        _touchGestureMode = TouchGestureMode::suppressed;
                    }
                }
                else if (distanceSquared >= kTouchOneFingerPanThreshold * kTouchOneFingerPanThreshold)
                {
                    _lastTouchToolTapTimestamp = 0;
                    BeginTouchPan(_touchGestureStart);
                    _touchGestureMode = TouchGestureMode::singlePan;
                    ContinueTouchPan(position);
                    return;
                }
            }
            else if (distanceSquared >= dragThresholdSquared)
            {
                StoreTouchPress(MouseState::leftPress, _touchGestureStart);
                _touchGestureMode = TouchGestureMode::singleDrag;
            }
        }
        _cursorState.position = position;
    }

    void SuppressRemainingTouch(SDL_FingerID releasedFingerId)
    {
        if (_primaryTouch.active && releasedFingerId == _primaryTouch.id && _secondaryTouch.active)
        {
            _primaryTouch = _secondaryTouch;
            _secondaryTouch = {};
        }
        else if (_secondaryTouch.active && releasedFingerId == _secondaryTouch.id)
        {
            _secondaryTouch = {};
        }
        else
        {
            _primaryTouch = {};
        }

        if (_primaryTouch.active)
        {
            _touchGestureMode = TouchGestureMode::suppressed;
        }
        else
        {
            ResetTouchGesture();
        }
    }

    void HandleTouchUp(const SDL_TouchFingerEvent& event)
    {
        const auto position = GetTouchPosition(event);
        const bool isPrimary = _primaryTouch.active && event.fingerId == _primaryTouch.id;
        const bool isSecondary = _secondaryTouch.active && event.fingerId == _secondaryTouch.id;
        if (!isPrimary && !isSecondary)
        {
            return;
        }

        if (_secondaryTouch.active)
        {
            if (_touchGestureMode == TouchGestureMode::multiPan)
            {
                StoreTouchRelease(MouseState::rightRelease, _cursorState.position);
            }
            else if (_touchGestureMode == TouchGestureMode::multiPending)
            {
                const auto centroid = GetTouchCentroid();
                if (CanUseTouchSecondaryAction(centroid))
                {
                    FireTouchSecondaryAction(centroid);
                }
            }
            SuppressRemainingTouch(event.fingerId);
            return;
        }

        switch (_touchGestureMode)
        {
            case TouchGestureMode::singlePending:
                if (event.timestamp - _touchGestureStartTimestamp >= kTouchLongPressTimeout)
                {
                    FireTouchLongPress(position);
                }
                else
                {
                    HandleTouchTap(event, position);
                }
                break;
            case TouchGestureMode::singleDrag:
                StoreTouchRelease(MouseState::leftRelease, position);
                break;
            case TouchGestureMode::singlePan:
                StoreTouchRelease(MouseState::rightRelease, _cursorState.position);
                break;
            case TouchGestureMode::suppressed:
            case TouchGestureMode::longPressFired:
            case TouchGestureMode::none:
            case TouchGestureMode::multiPending:
            case TouchGestureMode::multiPan:
            case TouchGestureMode::multiPinch:
            case TouchGestureMode::multiRotate:
            case TouchGestureMode::multiRemove:
                break;
        }
        ResetTouchGesture();
    }

    void HandleTouchHold()
    {
        if (_touchGestureMode == TouchGestureMode::multiPending && _primaryTouch.active && _secondaryTouch.active)
        {
            const auto holdDuration = SDL_GetTicks() - _touchGestureStartTimestamp;
            const auto centroid = GetTouchCentroid();
            if (holdDuration >= kTouchPaintHoldTimeout && CanEraseFootpathWithTouch(centroid))
            {
                _touchGestureMode = TouchGestureMode::multiRemove;
                _touchLastRemovePosition = centroid;
                FireTouchSecondaryAction(centroid);
            }
            return;
        }

        if (_touchGestureMode != TouchGestureMode::singlePending || !_primaryTouch.active)
        {
            return;
        }

        const auto holdDuration = SDL_GetTicks() - _touchGestureStartTimestamp;
        if (holdDuration >= kTouchPaintHoldTimeout && CanPaintWithTouch(_primaryTouch.position))
        {
            _lastTouchToolTapTimestamp = 0;
            StoreTouchPress(MouseState::leftPress, _primaryTouch.position);
            _touchGestureMode = TouchGestureMode::singleDrag;
        }
        else if (holdDuration >= kTouchLongPressTimeout)
        {
            FireTouchLongPress(_primaryTouch.position);
        }
    }
#endif
