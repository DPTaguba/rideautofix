# RideAutoFix Firebase setup

The Flutter client is configured for the Firebase project `rideautofix` on Android, iOS, and Web. Enable **Email/Password** under Firebase Authentication and create a Cloud Firestore database before running the app. Deploy `firestore.rules` (for example, with `firebase deploy --only firestore:rules`).

## Create the pre-made administrator

Firebase Auth accounts must be created in the Firebase project by its owner or a trusted server. The app intentionally does not contain an admin password or a client-side admin creation flow.

1. In Firebase Console → Authentication → Users, add `admin@rideautofix.com` as the administrator login and set its password there. Choose a private password and keep it out of the app source.
2. Copy its Firebase Auth UID.
3. In Firestore, create `users/{UID}` with fields `name` (string), `email` (string), and `role` (string set to `admin`). The password stays in Firebase Authentication and is never stored in Firestore.
4. Sign into the app using that account. It will open the admin dashboard. Customer registration always creates a `customer` role.

Firebase options in this project include Android, iOS, and Web only. Configure options for other targets before running them.

## Data collections

- `users/{uid}`: display name, phone, email, and role.
- `vehicles/{vehicleId}`: owner UID, vehicle type, brand, model, year, plate, and optional Cloudinary `photoUrl`.
- `services/{serviceId}`: service name, description, estimated price, and active flag.
- `appointments/{appointmentId}`: customer, selected service and vehicle snapshot, requested date/time/address, payment method/status, and appointment status.

Vehicle photos are uploaded directly to Cloudinary using the unsigned preset `autofixride` in cloud `udrczyzi`. The returned secure URL is saved as `photoUrl` on the vehicle document. Keep the preset unsigned for client uploads, and restrict its allowed formats and file size in Cloudinary settings.

Payments in this build record the chosen method and status. They do not charge cards or GCash; connect a trusted payment provider/server before accepting real electronic payments. Do not collect or store card numbers in Firestore.
