const admin = require('firebase-admin');

// Initialize Firebase Admin (make sure you have the serviceAccountKey.json)
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkPhotos() {
  const usersRef = db.collection('users');
  const snapshot = await usersRef.where('role', '==', 'student').get();

  let countWithPhoto = 0;
  snapshot.forEach(doc => {
    const data = doc.data();
    if (data.photoUrl || data.image || data.photoURL || data.profileUrl || data.imageUrl) {
        console.log(`User: ${data.name}, Username: ${data.username}, Photo: ${data.photoUrl || data.image || data.photoURL || data.profileUrl || data.imageUrl}`);
        countWithPhoto++;
    }
  });

  console.log(`Total students with a photo field: ${countWithPhoto}`);
}

checkPhotos();
