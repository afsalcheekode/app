const { initializeApp } = require('firebase/app');
const { getAuth, signInWithEmailAndPassword, updatePassword } = require('firebase/auth');
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

async function fixPasswords() {
  const centralStore = await getDoc(doc(db, 'app_data', 'central_store'));
  const teachers = centralStore.data().allTeachers;
  
  for (const t of teachers) {
    if (!['hsh', 'mun', 'ahs'].includes(t.username)) continue;
    
    const email = `${t.username}@harakat.com`;
    const targetPassword = getFirebasePassword(t.password);
    
    try {
      // Sign in with the old hardcoded password
      await signInWithEmailAndPassword(auth, email, '9605__');
      
      // Update to the correct password from central_store
      await updatePassword(auth.currentUser, targetPassword);
      console.log(`[SUCCESS] Updated ${t.username}'s password to match central_store (${t.password})`);
      
      await auth.signOut();
    } catch (e) {
      if (e.code === 'auth/invalid-credential') {
         // Maybe it's already updated? Let's try signing in with the target password
         try {
           await signInWithEmailAndPassword(auth, email, targetPassword);
           console.log(`[ALREADY OK] ${t.username} already has the correct password.`);
           await auth.signOut();
         } catch (e2) {
           console.log(`[FAILED] ${t.username} failed completely. Error: ${e2.code}`);
         }
      } else {
        console.log(`[FAILED] ${t.username} update failed. Error: ${e.code}`);
      }
    }
  }
  process.exit(0);
}

fixPasswords();
