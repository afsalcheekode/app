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

async function test() {
    console.log("Trying to sign in zayanhz02@v2.harakat.com...");
    try {
        const result = await signInWithEmailAndPassword(auth, 'zayanhz02@v2.harakat.com', 'hz0201');
        console.log("Sign in successful! UID:", result.user.uid);
        
        const userDoc = await getDoc(doc(db, 'users', result.user.uid));
        if (userDoc.exists()) {
            console.log("User doc exists:", userDoc.data());
        } else {
            console.log("User doc DOES NOT EXIST!");
        }
    } catch (e) {
        console.error("Sign in failed:", e);
    }
}

test().then(() => process.exit(0));
