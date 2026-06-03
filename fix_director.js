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

async function fixDirector() {
  try {
    const rawData = fs.readFileSync('temp_users.json', 'utf8');
    const data = JSON.parse(rawData);
    
    // We will update ALL director accounts to have the correct Arabic school name just in case!
    const directorUsernames = [
      'hsh.dtcr', 'dtcr.hsh', 'director', 'hsh.director', 'hsh.dirocter', 'minad', 'system.admin'
    ];
    
    for (const u of data.users) {
      if (u.email) {
        let username = u.email.split('@')[0];
        if (directorUsernames.includes(username)) {
          await setDoc(doc(db, 'users', u.localId), {
            schoolName: 'كلية حياة الإسلام', 
            academic_director: 'Hafiz Shafeeq Hashimi'
          }, { merge: true });
        }
      }
    }
    
    console.log('Fixed ALL director accounts successfully!');
    process.exit(0);
  } catch (error) {
    console.error("Error:", error);
    process.exit(1);
  }
}

fixDirector();
