const { initializeApp } = require('firebase/app');
const { getFirestore, doc, setDoc } = require('firebase/firestore');
const fs = require('fs');

const firebaseConfig = {
  apiKey: "AIzaSyDtzmMvUktdEvlK-_6_vB_k3O6paWlznWQ",
  appId: "1:313350964672:web:0a5ba8a1d990c433cef425",
  projectId: "studio-6116270073-a85c2",
  authDomain: "studio-6116270073-a85c2.firebaseapp.com",
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function cleanupData() {
  try {
    const rawData = fs.readFileSync('temp_users.json', 'utf8');
    const data = JSON.parse(rawData);
    
    const knownTeachers = ['mah04', 'ahs04', 'hsh04', 'mun04'];
    const validClasses = ['bs01', 'bs02', 'hs01', 'hs02', 'jnr01', 'jnr02', 'hz01', 'hz02', 'hz03', 'hz04'];
    
    const allStudents = [];
    const allTeachers = [];
    const usersToDelete = [];
    
    for (const user of data.users) {
      if (!user.email) continue;
      
      let username = user.email.split('@')[0];
      let keep = false;
      let role = null;
      let className = null;
      let dept = null;
      
      if (username === 'hsh.dtcr') {
        keep = true;
      } else if (knownTeachers.includes(username)) {
        keep = true;
        role = 'teacher';
      } else {
        for (const cls of validClasses) {
          if (username.endsWith(cls)) {
            keep = true;
            role = 'student';
            className = cls;
            dept = cls.startsWith('hz') ? 'HIFZ' : "DA'WA";
            break;
          }
        }
      }
      
      if (keep) {
        if (role === 'student') {
          allStudents.push({
            username: username,
            name: username.toUpperCase(),
            className: className,
            schoolName: 'كلية حياة الإسلام',
            dept: dept
          });
        } else if (role === 'teacher') {
          allTeachers.push({
            username: username,
            name: username.toUpperCase(),
            schoolName: 'كلية حياة الإسلام'
          });
        }
      } else {
        usersToDelete.push(user.localId);
      }
    }
    
    const classDepts = {};
    for (const c of validClasses) {
      classDepts[c] = c.startsWith('hz') ? 'HIFZ' : "DA'WA";
    }
    
    await setDoc(doc(db, 'app_data', 'central_store'), {
      allStudents: allStudents,
      allTeachers: allTeachers,
      allClasses: validClasses,
      classDepts: classDepts
    }, { merge: true });
    
    console.log(`central_store perfectly rebuilt with ${allStudents.length} students and ${allTeachers.length} teachers.`);
    
    // Write UIDs to delete to a file so bash can delete them
    fs.writeFileSync('uids_to_delete.txt', usersToDelete.join(' '));
    console.log(`Wrote ${usersToDelete.length} UIDs to delete.`);
    
    process.exit(0);
  } catch (error) {
    console.error("Error during cleanup:", error);
    process.exit(1);
  }
}

cleanupData();
