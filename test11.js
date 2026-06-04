const { initializeApp } = require('firebase/app');
const { getFirestore, doc, setDoc } = require('firebase/firestore');
const { getAuth, signInWithEmailAndPassword } = require('firebase/auth');

const firebaseConfig = {
    apiKey: 'AIzaSyDtzmMvUktdEvlK-_6_vB_k3O6paWlznWQ',
    appId: '1:313350964672:web:0a5ba8a1d990c433cef425',
    projectId: 'studio-6116270073-a85c2',
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

async function test() {
    console.log("Signing in...");
    const cred = await signInWithEmailAndPassword(auth, 'zayanhz02@v2.harakat.com', 'hz0201');
    const uid = cred.user.uid;
    console.log("Signed in as", uid);

    try {
        console.log("Trying to write to users/" + uid);
        await setDoc(doc(db, 'users', uid), { test: 'test' }, { merge: true });
        console.log("Write success!");
    } catch (e) {
        console.log("Write failed:", e);
    }
}

test().then(() => process.exit(0));
