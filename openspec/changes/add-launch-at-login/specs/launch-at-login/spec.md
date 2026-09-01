## Purpose

Defines whether the app starts automatically when the user logs in: the user-facing setting and its default, the relationship between the user's remembered intent and the operating system's own login-items registration, and how the app surfaces the states where registration is pending approval, absent, or unavailable.

## ADDED Requirements

### Requirement: Open-at-login setting

The settings window SHALL expose an "open at login" toggle that controls whether the app starts automatically when the user logs in. The setting SHALL default to off, so the app never registers itself as a login item unless the user asks for it. Turning the toggle on SHALL register the app to launch at login; turning it off SHALL remove that registration.

#### Scenario: Default is off on first launch
- **WHEN** the app launches with no persisted value for the open-at-login setting
- **THEN** the setting is off
- **AND** the app has not registered itself to launch at login

#### Scenario: Turning the setting on registers the app
- **WHEN** the user turns the open-at-login toggle on
- **THEN** the app registers itself to launch at login
- **AND** the app starts automatically at the user's next login, subject to any approval the operating system requires

#### Scenario: Turning the setting off removes the registration
- **WHEN** the user turns the open-at-login toggle off
- **THEN** the app's login-item registration is removed
- **AND** the app does not start automatically at the user's next login

### Requirement: Registration appears as an application in Login Items

The app SHALL register itself as an application that opens at login, not as a background service. When registered, it SHALL appear in the operating system's login items settings in the list of applications that open at login, identified by the app's own name and icon, where the user can remove it directly.

#### Scenario: Registered app is listed as an application
- **WHEN** the open-at-login setting is on and registration has succeeded
- **THEN** the app is listed among the applications that open at login in the system's login items settings
- **AND** it is not listed as an opaque background item

### Requirement: Operating system is the source of truth

The operating system's registration state SHALL be the authority on whether the app actually launches at login; the persisted setting SHALL record only the user's intent. The toggle SHALL reflect the operating system's current registration state rather than the persisted intent alone, so it never reports that the app opens at login when the operating system has it disabled, nor the reverse.

#### Scenario: User disables the login item outside the app
- **WHEN** the user removes or disables the app's login item in the operating system's settings
- **AND** the app's settings window is then brought to the front
- **THEN** the open-at-login toggle shows that the app no longer opens at login

#### Scenario: User enables the login item outside the app
- **WHEN** the user enables the app's login item in the operating system's settings
- **AND** the app's settings window is then brought to the front
- **THEN** the open-at-login toggle shows that the app opens at login

#### Scenario: Toggle reflects actual state on launch
- **WHEN** the app launches
- **THEN** the open-at-login toggle shows the operating system's current registration state

### Requirement: Reconciliation of intent against actual state

On launch, the app SHALL compare the user's persisted intent against the operating system's registration state and reconcile them. When the user's intent is on but the app is not registered — including after the installed application bundle has been replaced by an upgrade — the app SHALL re-register itself without requiring the user to toggle the setting again. When the user's intent is off but the app is registered, the app SHALL adopt the operating system's state as the user's intent rather than silently unregistering.

#### Scenario: Registration lost after an upgrade is restored
- **WHEN** the user's persisted intent is on
- **AND** on launch the operating system reports that the app is not registered to launch at login
- **THEN** the app registers itself again
- **AND** the user is not required to change the toggle to restore the behavior

#### Scenario: Externally added registration is adopted as intent
- **WHEN** the user's persisted intent is off
- **AND** on launch the operating system reports that the app is registered to launch at login
- **THEN** the app leaves the registration in place
- **AND** the persisted intent is updated to on so the toggle and the operating system agree

### Requirement: Pending approval is surfaced to the user

When the operating system reports that the app's login-item registration requires the user's approval before it takes effect, the app SHALL say so in the settings window rather than presenting the setting as fully enabled, and SHALL offer a control that opens the operating system's login items settings so the user can grant that approval.

#### Scenario: Approval required after registering
- **WHEN** registration succeeds but the operating system reports that it requires approval
- **THEN** the settings window explains that the login item is awaiting approval in the system's settings
- **AND** a control is offered that opens the system's login items settings

#### Scenario: Approval granted
- **WHEN** the user approves the login item in the system's settings
- **AND** the app's settings window is then brought to the front
- **THEN** the settings window no longer shows the pending-approval explanation

### Requirement: Setting is unavailable when the app is not running from an installed bundle

Registration is only possible for an app running from an application bundle. When the app is running outside one — for example a development build launched directly as an executable — the app SHALL present the open-at-login toggle as disabled with an explanation of why it is unavailable, rather than offering a control that cannot work.

#### Scenario: Running outside an application bundle
- **WHEN** the app is running from an executable that is not inside an application bundle
- **THEN** the open-at-login toggle is disabled
- **AND** the settings window explains that the setting is available only when running the installed application

#### Scenario: Running from the installed bundle
- **WHEN** the app is running from an application bundle
- **THEN** the open-at-login toggle is enabled and usable

### Requirement: Registration failures are non-fatal

A failure to register or unregister the login item SHALL NOT crash the app or leave the toggle asserting a state the operating system does not hold. After a failed attempt, the toggle SHALL show the operating system's actual state, and the rest of the app SHALL continue to function normally.

#### Scenario: Registration attempt fails
- **WHEN** the user turns the open-at-login toggle on
- **AND** the operating system rejects the registration
- **THEN** the app does not crash
- **AND** the toggle shows that the app does not open at login
- **AND** all other app functionality continues to work
