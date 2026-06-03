const admin = require("firebase-admin");

admin.initializeApp({
  projectId: "studio-6116270073-a85c2"
});

admin.auth().updateUser("PaJmlJMLZQapQPAAHDM1rdsuX2l1", {
  password: "9605__"
})
  .then((userRecord) => {
    console.log("Successfully updated user", userRecord.uid);
    process.exit(0);
  })
  .catch((error) => {
    console.log("Error updating user:", error);
    process.exit(1);
  });
