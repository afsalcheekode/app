const { initializeApp } = require('firebase/app');
const { getFirestore, doc, setDoc, getDoc } = require('firebase/firestore');

const firebaseConfig = {
  apiKey: "AIzaSyDtzmMvUktdEvlK-_6_vB_k3O6paWlznWQ",
  appId: "1:313350964672:web:0a5ba8a1d990c433cef425",
  projectId: "studio-6116270073-a85c2",
  authDomain: "studio-6116270073-a85c2.firebaseapp.com",
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function fixSchoolNameMismatch() {
  try {
    const centralStoreRef = doc(db, 'app_data', 'central_store');
    const snapshot = await getDoc(centralStoreRef);
    
    if (snapshot.exists()) {
      const data = snapshot.data();
      const allStudents = data.allStudents || [];
      const allTeachers = data.allTeachers || [];
      
      let updatedStudents = 0;
      let updatedTeachers = 0;
      
      for (const s of allStudents) {
        if (s.schoolName === 'Hayathul Islam') {
          s.schoolName = 'كلية حياة الإسلام';
          updatedStudents++;
        }
      }
      for (const t of allTeachers) {
        if (t.schoolName === 'Hayathul Islam') {
          t.schoolName = 'كلية حياة الإسلام';
          updatedTeachers++;
        }
      }
      
      // Update central_store
      await setDoc(centralStoreRef, {
        allStudents: allStudents,
        allTeachers: allTeachers
      }, { merge: true });
      
      console.log(`Fixed schoolName mismatch for ${updatedStudents} students and ${updatedTeachers} teachers in central_store.`);
    }
    
    // We should also delete the other duplicate director accounts if the user wants.
    // The user said: "you could delete all other accounts never need to recover and that user id's can reuse. only exist this one."
    // Let's just focus on fixing the mismatch first so the UI populates.
    
    process.exit(0);
  } catch (error) {
    console.error("Error:", error);
    process.exit(1);
  }
}

fixSchoolNameMismatch();
