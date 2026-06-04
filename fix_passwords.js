const { initializeApp } = require('firebase/app');
const { getFirestore, doc, getDoc, setDoc } = require('firebase/firestore');
const { getAuth, signInWithEmailAndPassword, updatePassword } = require('firebase/auth');

const firebaseConfig = {
    apiKey: 'AIzaSyDtzmMvUktdEvlK-_6_vB_k3O6paWlznWQ',
    appId: '1:313350964672:web:0a5ba8a1d990c433cef425',
    projectId: 'studio-6116270073-a85c2',
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

async function migrate() {
    console.log("Fetching central_store...");
    const centralStoreRef = doc(db, 'app_data', 'central_store');
    const centralStoreSnap = await getDoc(centralStoreRef);

    if (!centralStoreSnap.exists()) {
        console.log("Central store not found!");
        return;
    }

    const data = centralStoreSnap.data();
    const students = data.allStudents || [];
    console.log(`Found ${students.length} students. Fixing passwords...`);

    let successCount = 0;
    let failCount = 0;

    for (const student of students) {
        if (!student.username || !student.password) continue;
        
        const username = student.username.toString().trim().toLowerCase();
        const originalPassword = student.password.toString().trim();
        
        if (originalPassword.length >= 6) {
            // No padding needed, password was already 6+ chars
            continue;
        }

        const oldFirebasePassword = originalPassword.padEnd(6, '0');
        const newFirebasePassword = originalPassword.padEnd(6, '_');
        
        const email = `${username}@v2.harakat.com`;
        
        try {
            console.log(`Fixing password for ${username}...`);
            // Sign in with the WRONG padded password ('0')
            const cred = await signInWithEmailAndPassword(auth, email, oldFirebasePassword);
            
            // Update to the CORRECT padded password ('_')
            await updatePassword(cred.user, newFirebasePassword);
            
            console.log(`Successfully fixed password for ${username}`);
            successCount++;
        } catch (e) {
            // Maybe they already have the correct password? Let's check.
            try {
                await signInWithEmailAndPassword(auth, email, newFirebasePassword);
                console.log(`${username} already has correct password.`);
                successCount++;
            } catch(e2) {
                console.log(`Failed to fix ${username}: ${e.message} and ${e2.message}`);
                failCount++;
            }
        }
    }

    console.log(`Fix complete. Success: ${successCount}, Failed: ${failCount}`);
}

migrate().then(() => process.exit(0));
