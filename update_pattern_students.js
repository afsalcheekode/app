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

function getInitials(name) {
    if (!name) return 'xx';
    const parts = name.trim().split(/\s+/);
    if (parts.length >= 2) {
        return (parts[0][0] + parts[1][0]).toLowerCase();
    } else {
        return name.length >= 2 ? name.substring(0, 2).toLowerCase() : (name[0] + name[0]).toLowerCase();
    }
}

const sleep = ms => new Promise(r => setTimeout(r, ms));

async function update() {
    const centralStoreRef = doc(db, 'app_data', 'central_store');
    const centralStoreSnap = await getDoc(centralStoreRef);
    const data = centralStoreSnap.data();

    const students = data.allStudents || [];
    let counter = 1;

    let updatedList = [];

    for (let i = 0; i < students.length; i++) {
        if (students[i].schoolName === 'كلية حياة الإسلام') {
            const initials = getInitials(students[i].name);
            const indexStr = counter.toString().padStart(2, '0');
            const targetUsername = `${initials}ustd${indexStr}`;
            const targetPassword = `${initials}pstd${indexStr}`;
            
            if (students[i].username !== targetUsername) {
                const oldUsername = students[i].username;
                const oldPassword = students[i].password;
                
                // Construct the old email based on whether it uses the old `studentXX` pattern or the even older ones
                let oldEmail = students[i].email;
                if (!oldEmail) {
                    oldEmail = `${oldUsername}@v2.harakat.com`;
                }

                const oldPaddedPassword = oldPassword.length < 6 ? oldPassword.padEnd(6, '_') : oldPassword;
                
                const newUsername = targetUsername;
                const newPassword = targetPassword;
                const newEmail = `${newUsername}@v2.harakat.com`;

                let uid;
                console.log(`Updating ${oldUsername} (${students[i].name}) -> ${newUsername}`);

                try {
                    const cred = await signInWithEmailAndPassword(auth, oldEmail, oldPaddedPassword);
                    uid = cred.user.uid;
                    await updateEmail(cred.user, newEmail);
                    await updatePassword(cred.user, newPassword);
                    await sleep(1000); // Wait 1 second to avoid rate limiting
                } catch (e) {
                    console.log(`Failed to login old account ${oldUsername}. Error: ${e.message}. Attempting to create new one...`);
                    try {
                        const cred2 = await createUserWithEmailAndPassword(auth, newEmail, newPassword);
                        uid = cred2.user.uid;
                        await sleep(1000); // Wait 1 second
                    } catch(e2) {
                        if (e2.code === 'auth/email-already-in-use') {
                            try {
                                const cred3 = await signInWithEmailAndPassword(auth, newEmail, newPassword);
                                uid = cred3.user.uid;
                            } catch(e3) {
                                console.log(`Error completely: ${e3.message}`);
                                // Let it fail but increment counter
                            }
                        } else {
                            console.log(`Error creating new: ${e2.message}`);
                            // Keep going but we failed this user
                        }
                    }
                }

                if (uid) {
                    students[i].username = newUsername;
                    students[i].password = newPassword;
                    students[i].uid = uid;
                    students[i].email = newEmail;

                    const userData = { ...students[i], role: 'student' };
                    await setDoc(doc(db, 'users', uid), userData, { merge: true });
                }
            } else {
                console.log(`Skipping ${students[i].name}, already updated to ${students[i].username}`);
            }

            updatedList.push({
                name: students[i].name,
                class: students[i].std,
                newUsername: students[i].username,
                newPassword: students[i].password
            });

            counter++;
        }
    }

    data.allStudents = students;
    await setDoc(centralStoreRef, data, { merge: true });

    console.log(`Updated central store.`);
    
    const fs = require('fs');
    fs.writeFileSync('pattern_credentials.json', JSON.stringify(updatedList, null, 2));
}

update().then(() => process.exit(0));
