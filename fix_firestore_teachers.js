const fs = require('fs');
const { initializeApp } = require('firebase/app');
const { getFirestore, doc, setDoc } = require('firebase/firestore');

const firebaseConfig = {
  apiKey: "AIzaSyDtzmMvUktdEvlK-_6_vB_k3O6paWlznWQ",
  appId: "1:313350964672:web:0a5ba8a1d990c433cef425",
  projectId: "studio-6116270073-a85c2",
  authDomain: "studio-6116270073-a85c2.firebaseapp.com",
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function fixFirestoreUsers() {
  try {
    const rawData = fs.readFileSync('new_auth.json', 'utf8');
    const authData = JSON.parse(rawData);
    
    const targets = ['hsh@harakat.com', 'mun@harakat.com', 'ahs@harakat.com', 'mah@harakat.com'];
    
    for (const u of authData.users) {
      if (targets.includes(u.email)) {
        const username = u.email.split('@')[0];
        let role = 'teacher';
        
        await setDoc(doc(db, 'users', u.localId), {
          uid: u.localId,
          email: u.email,
          username: username,
          name: username.toUpperCase(),
          role: role,
          schoolName: 'كلية حياة الإسلام'
        }, { merge: true });
        
        console.log(`Created Firestore doc for ${username} with NEW UID ${u.localId}`);
      }
    }
    
    process.exit(0);
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
}

fixFirestoreUsers();
