const { initializeApp } = require('firebase/app');
const { getAuth, signInWithEmailAndPassword } = require('firebase/auth');
const { getFirestore, doc, getDoc } = require('firebase/firestore');

const app = initializeApp({
  apiKey: "AIzaSyDtzmMvUktdEvlK-_6_vB_k3O6paWlznWQ",
  appId: "1:313350964672:web:0a5ba8a1d990c433cef425",
  projectId: "studio-6116270073-a85c2"
});

const auth = getAuth(app);
const db = getFirestore(app);

function getFirebasePassword(p) {
  p = p.trim();
  while (p.length < 6) p += '_';
  return p;
}

async function testAllTeachers() {
  const centralStore = await getDoc(doc(db, 'app_data', 'central_store'));
  const teachers = centralStore.data().allTeachers;
  
  for (const t of teachers) {
    if (!['hsh', 'mun', 'ahs', 'mah'].includes(t.username)) continue;
    
    const email = `${t.username}@harakat.com`;
    const password = getFirebasePassword(t.password);
    
    try {
      await signInWithEmailAndPassword(auth, email, password);
      console.log(`[SUCCESS] ${t.username} signed in successfully with pass: ${t.password}`);
      
      const userDoc = await getDoc(doc(db, 'users', auth.currentUser.uid));
      if (!userDoc.exists()) {
        console.log(`  -> BUT missing Firestore doc for ${auth.currentUser.uid}!`);
      } else {
        console.log(`  -> AND Firestore doc exists!`);
      }
      
      await auth.signOut();
    } catch (e) {
      console.log(`[FAILED] ${t.username} failed to sign in with ${t.password} (padded: ${password}). Error: ${e.code}`);
    }
  }
  process.exit(0);
}

testAllTeachers();
