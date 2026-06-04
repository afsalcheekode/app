const { initializeApp } = require('firebase/app');
const { getAuth, signInWithEmailAndPassword } = require('firebase/auth');
const { getFirestore, doc, getDoc } = require('firebase/firestore');

const firebaseConfig = {
    apiKey: 'AIzaSyDtzmMvUktdEvlK-_6_vB_k3O6paWlznWQ',
    appId: '1:313350964672:web:0a5ba8a1d990c433cef425',
    projectId: 'studio-6116270073-a85c2',
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

async function check() {
    const centralStoreRef = doc(db, 'app_data', 'central_store');
    const centralStoreSnap = await getDoc(centralStoreRef);
    const data = centralStoreSnap.data();

    // Pick a student
    const student = data.allStudents.find(s => s.username === 'ahsanhs01');
    const username = student.username;
    const password = student.password;

    const email = `${username}@v2.harakat.com`;
    console.log(`Trying to login with ${email} / ${password}`);

    try {
        const cred = await signInWithEmailAndPassword(auth, email, password);
        console.log("Login successful! UID:", cred.user.uid);
    } catch (e) {
        console.log("Login failed:", e.code, e.message);
    }
}

check().then(() => process.exit(0));
