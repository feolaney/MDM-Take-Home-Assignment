# Mandating a 10-minute automatic lock on macOS and Windows

To mandate an automatic screen lock or screen saver after 10 minutes of inactivity on both macOS and Windows, the approach is essentially the same. You use the native management frameworks exposed through Jamf and Intune. Each platform enforces through its own controls, but the goal and outcome line up.

## macOS with Jamf

Historically this has been done with a configuration profile. Jamf has been investing in Blueprints, which are intended to take over Apple framework settings and organize them in one place. Blueprints support classic payloads and new profiles that use Apple’s DDM framework. The point is not to change the setting itself, but to align with where Jamf and Apple are going and to benefit from better, stateful communication in DDM.

Functionally this is a small change. The enforcement is still a managed setting on the device. Moving to a Blueprint just future-proofs the policy and should improve reliability as devices reconcile state.

In Blueprints, either create a new Blueprint or add the Screen Saver payload to an existing one that applies broadly. Set the following:
- Require password after screen saver or sleep: enabled
- Password delay: 0 seconds
- Idle time: 10 minutes

Because this uses Apple’s management framework, these preferences are locked as long as the Jamf management profile is installed. Users will see the settings but will not be able to change them. For verification, check Blueprint install status in Jamf Pro. If you want more granular reporting, add a custom Extension Attribute and surface it in smart groups or dashboards.

## Windows with Intune

On Windows you do the same thing conceptually using a Settings Catalog configuration. Create a configuration profile targeting Windows 10 or later and set the inactivity limit.

Configure:
- Local Policies Security Options
    Interactive logon
    Machine inactivity limit: 600 seconds

That setting locks the computer after 10 minutes of inactivity. If you want a standard corporate screen saver you can create another Settings Catalog profile, but it is not required to meet the security mandate. Users attempting to change the timeout will see it is managed by the organization. For verification, review the profile’s install state in Intune or run a deployment report.

## Exceptions

Exceptions exist on both platforms, but the mechanics differ slightly.
- Intune: add an excluded group to the profile assignments.
- Jamf with configuration profiles: add an exclusion to the scope.
- Jamf with Blueprints: Blueprints include targets through smart groups, so place the exception logic in the smart group criteria. Devices that meet the exception should simply not match the include rules.

## Communication

Send an announcement through the most visible internal channel. State what is changing, what users will see, and why the change is required for security compliance. If you want a reference, link to a short KB that explains the inactivity lock. In this case a KB is optional since the behavior is straightforward.

## Rollout

Normally I would stage this kind of change through a classic tiered deployment—canary, pilot, then broad production—to catch corner cases when new payloads or novel workflows roll out. In this scenario the payloads lean entirely on battle-tested Apple and Microsoft frameworks with settings that have been in place for years, so the risk profile is low. A pragmatic compromise is to scope the new Jamf Blueprint and Intune profile to IT endpoints for about a week, verify there are no unexpected regressions, and then expand to the full population in a single wave following the communication.

### Compliance reporting metrics

- **Jamf**: Dashboard card and scheduled report keyed on the Blueprint smart group. Metrics: number of devices with the Blueprint installed, % compliant vs total scoped, count of devices reporting “Failed” or “Pending” state for the Screen Saver payload.
- **Intune**: Device configuration profile report filtered to the relevant Settings Catalog profile. Metrics: Success/Conflict/Error counts, % devices reporting “Succeeded,” list of failed device/resource IDs for remediation.
- **Cross-platform rollup**: Weekly combined snapshot that shows total macOS+Windows population, total compliant, total exceptions (justified, approved), average remediation time from failure detection to success. This is what security and audit review.

Honestly though any of this reporting would be moved to something like Airtable as simple number reporting can be manually and even automatically with API use be gathered the presentation would be very basic.
