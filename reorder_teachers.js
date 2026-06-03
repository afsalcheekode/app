const { initializeApp } = require('firebase/app');
const { getAuth, createUserWithEmailAndPassword } = require('firebase/auth');
const { getFirestore, doc, setDoc } = require('firebase/firestore');

const firebaseConfig = {
  apiKey: "AIzaSyDtzmMvUktdEvlK-_6_vB_k3O6paWlznWQ",
  appId: "1:313350964672:web:0a5ba8a1d990c433cef425",
  projectId: "studio-6116270073-a85c2",
  authDomain: "studio-6116270073-a85c2.firebaseapp.com",
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

async function renameAndReorder() {
  const newTeachers = [
    { username: 'hsh', name: 'HSH', schoolName: 'كلية حياة الإسلام', password: '9605' },
    { username: 'mun', name: 'MUN', schoolName: 'كلية حياة الإسلام', password: '9605' },
    { username: 'ahs', name: 'AHS', schoolName: 'كلية حياة الإسلام', password: '9605' },
    { username: 'mah', name: 'MAH', schoolName: 'كلية حياة الإسلام', password: '9605' }
  ];

  for (const t of newTeachers) {
    try {
      // Create account in Auth with pass 9605
      const email = `${t.username}@harakat.com`;
      // firebase requires 6 chars pass, auth_service pads it: '9605__'
      const pass = '9605__'; 
      await createUserWithEmailAndPassword(auth, email, pass);
      console.log(`Created ${email}`);
    } catch (e) {
      if (e.code === 'auth/email-already-in-use') {
        console.log(`${t.username} already exists in auth`);
      } else {
        console.error(`Failed to create ${t.username}:`, e);
      }
    }
  }

  try {
    // Reorder and rename in central_store
    const centralStoreRef = doc(db, 'app_data', 'central_store');
    await setDoc(centralStoreRef, {
      allTeachers: newTeachers.map(t => ({
        username: t.username,
        name: t.name,
        schoolName: t.schoolName
      }))
    }, { merge: true });
    
    console.log('Successfully reordered and renamed teachers in central_store!');
    process.exit(0);
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
}

renameAndReorder();
