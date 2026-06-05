const { initializeApp } = require('firebase/app');
const { getFirestore, doc, getDoc, setDoc } = require('firebase/firestore');
const { getAuth, signInWithEmailAndPassword, updateEmail, updatePassword, createUserWithEmailAndPassword } = require('firebase/auth');

const firebaseConfig = {
    apiKey: 'AIzaSyDtzmMvUktdEvlK-_6_vB_k3O6paWlznWQ',
    appId: '1:313350964672:web:0a5ba8a1d990c433cef425',
    projectId: 'studio-6116270073-a85c2',
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

async function update() {
    const centralStoreRef = doc(db, 'app_data', 'central_store');
    const centralStoreSnap = await getDoc(centralStoreRef);
    const data = centralStoreSnap.data();

    const students = data.allStudents || [];
    let counter = 1;

    let updatedList = [];

    for (let i = 0; i < students.length; i++) {
        if (students[i].schoolName === 'كلية حياة الإسلام') {
            const oldUsername = students[i].username;
            const oldPassword = students[i].password;
            const oldEmail = `${oldUsername}@v2.harakat.com`;
            const oldPaddedPassword = oldPassword.length < 6 ? oldPassword.padEnd(6, '_') : oldPassword;

            const newUsername = `student${counter.toString().padStart(2, '0')}`;
            const newPassword = `pass${counter.toString().padStart(2, '0')}`; // 6 chars: p a s s 0 1
            const newEmail = `${newUsername}@v2.harakat.com`;

            let uid;
            
            console.log(`Updating ${oldUsername} -> ${newUsername}`);

            try {
                // Try to sign in to the old account to update it
                const cred = await signInWithEmailAndPassword(auth, oldEmail, oldPaddedPassword);
                uid = cred.user.uid;
                await updateEmail(cred.user, newEmail);
                await updatePassword(cred.user, newPassword);
            } catch (e) {
                console.log(`Failed to login old account ${oldUsername}. Attempting to create new one...`);
                // Create new account if old one fails
                try {
                    const cred2 = await createUserWithEmailAndPassword(auth, newEmail, newPassword);
                    uid = cred2.user.uid;
                } catch(e2) {
                    // Maybe the new account already exists?
                    if (e2.code === 'auth/email-already-in-use') {
                        try {
                            const cred3 = await signInWithEmailAndPassword(auth, newEmail, newPassword);
                            uid = cred3.user.uid;
                        } catch(e3) {
                            console.log(`Error completely: ${e3.message}`);
                            continue;
                        }
                    } else {
                        console.log(`Error creating new: ${e2.message}`);
                        continue;
                    }
                }
            }

            // Update in central_store array
            students[i].username = newUsername;
            students[i].password = newPassword;
            students[i].uid = uid;
            students[i].email = newEmail;

            // Update in users collection
            const userData = { ...students[i], role: 'student' };
            await setDoc(doc(db, 'users', uid), userData, { merge: true });

            updatedList.push({
                name: students[i].name,
                class: students[i].std,
                newUsername: newUsername,
                newPassword: newPassword
            });

            counter++;
        }
    }

    // Save central_store
    data.allStudents = students;
    await setDoc(centralStoreRef, data, { merge: true });

    console.log(`Updated ${updatedList.length} students.`);
    
    // Write out the list for the user
    const fs = require('fs');
    fs.writeFileSync('new_credentials.json', JSON.stringify(updatedList, null, 2));
}

update().then(() => process.exit(0));
