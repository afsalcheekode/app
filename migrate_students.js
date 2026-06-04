const { initializeApp } = require('firebase/app');
const { getFirestore, doc, getDoc, setDoc } = require('firebase/firestore');
const { getAuth, createUserWithEmailAndPassword, signInWithEmailAndPassword, deleteUser } = require('firebase/auth');

const admin = require('firebase-admin');

// Since we don't have the service account key easily accessible, we will use the Client SDK.
// But wait, the client SDK's createUserWithEmailAndPassword signs the user in!
// If we loop and create 54 users, we will sign in 54 times. That's fine.

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
    console.log(`Found ${students.length} students. Migrating...`);

    let successCount = 0;
    let failCount = 0;

    for (const student of students) {
        if (!student.username || !student.password) continue;
        
        const username = student.username.toString().trim().toLowerCase();
        const originalPassword = student.password.toString().trim();
        let firebasePassword = originalPassword;
        if (firebasePassword.length < 6) {
            firebasePassword = firebasePassword.padEnd(6, '0');
        }

        const email = `${username}@v2.harakat.com`;
        
        try {
            console.log(`Processing ${username}...`);
            let uid;
            
            // Try to create
            try {
                const cred = await createUserWithEmailAndPassword(auth, email, firebasePassword);
                uid = cred.user.uid;
            } catch (e) {
                if (e.code === 'auth/email-already-in-use') {
                    // Try to sign in to get the UID
                    try {
                        const cred2 = await signInWithEmailAndPassword(auth, email, firebasePassword);
                        uid = cred2.user.uid;
                    } catch (e2) {
                        console.log(`Failed to sign in existing user ${username}:`, e2.message);
                        failCount++;
                        continue;
                    }
                } else {
                    console.log(`Failed to create user ${username}:`, e.message);
                    failCount++;
                    continue;
                }
            }

            // Write to Firestore
            const matchData = {
                ...student,
                role: 'student',
                email: email,
                uid: uid
            };

            await setDoc(doc(db, 'users', uid), matchData, { merge: true });
            console.log(`Successfully migrated ${username}`);
            successCount++;
        } catch (e) {
            console.log(`Error processing ${username}:`, e.message);
            failCount++;
        }
    }

    console.log(`Migration complete. Success: ${successCount}, Failed: ${failCount}`);
}

migrate().then(() => process.exit(0));
