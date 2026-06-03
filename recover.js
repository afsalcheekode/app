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

async function recoverData() {
  try {
    const rawData = fs.readFileSync('temp_users.json', 'utf8');
    const data = JSON.parse(rawData);
    
    const allStudents = [];
    const allTeachers = [];
    
    const knownTeachers = ['mah04', 'ahs04', 'hsh04', 'mun04'];
    const knownAdmins = ['minad', 'director', 'hsh.dtcr', 'system.admin'];
    
    const dawaClasses = ['bs01', 'bs02', 'hs01', 'hs02', 'jnr01', 'jnr02'];
    const hifzClasses = ['hz01', 'hz02', 'hz03', 'hz04'];
    const validClasses = [...dawaClasses, ...hifzClasses];
    
    for (const user of data.users) {
      if (!user.email) continue;
      
      let username = user.email.split('@')[0];
      let role = 'student'; 
      let className = null;
      let dept = null;
      
      if (knownTeachers.includes(username)) {
        role = 'teacher';
      } else if (knownAdmins.includes(username)) {
        role = username === 'minad' ? 'admin' : 'director';
      } else {
        // Find if they match a valid class
        for (const cls of validClasses) {
          if (username.endsWith(cls)) {
            className = cls;
            dept = dawaClasses.includes(cls) ? "DA'WA" : "HIFZ";
            break;
          }
        }
        
        // If they don't match a valid class, we ignore them for the active lists!
        if (!className) {
          continue; 
        }
      }
      
      const userData = {
        uid: user.localId,
        username: username,
        role: role,
        name: username.toUpperCase(), 
        schoolName: 'Hayathul Islam',
        email: user.email
      };
      
      if (role === 'student') {
        userData.className = className;
        userData.dept = dept;
      }
      
      await setDoc(doc(db, 'users', user.localId), userData, { merge: true });
      
      if (role === 'student') {
        allStudents.push({
          username: username,
          name: username.toUpperCase(),
          className: className,
          schoolName: 'Hayathul Islam',
          dept: dept
        });
      } else if (role === 'teacher') {
        allTeachers.push({
          username: username,
          name: username.toUpperCase(),
          schoolName: 'Hayathul Islam'
        });
      }
    }
    
    const classDepts = {};
    for (const c of dawaClasses) classDepts[c] = "DA'WA";
    for (const c of hifzClasses) classDepts[c] = "HIFZ";
    
    await setDoc(doc(db, 'app_data', 'central_store'), {
      allStudents: allStudents,
      allTeachers: allTeachers,
      allClasses: validClasses,
      classDepts: classDepts
    }, { merge: true });
    
    console.log(`Successfully recovered ${allStudents.length} students and ${allTeachers.length} teachers!`);
    process.exit(0);
  } catch (error) {
    console.error("Error during recovery:", error);
    process.exit(1);
  }
}

recoverData();
