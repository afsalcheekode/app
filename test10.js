const { initializeApp } = require('firebase/app');
const { getAuth, signInWithEmailAndPassword, createUserWithEmailAndPassword, deleteUser } = require('firebase/auth');

const firebaseConfig = {
    apiKey: 'AIzaSyDtzmMvUktdEvlK-_6_vB_k3O6paWlznWQ',
    appId: '1:313350964672:web:0a5ba8a1d990c433cef425',
    projectId: 'studio-6116270073-a85c2',
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);

async function test() {
    const email = 'zayanhz02@v2.harakat.com';
    const password = 'hz0201';

    console.log(`Trying to sign in ${email}...`);
    try {
        const cred = await signInWithEmailAndPassword(auth, email, password);
        console.log("Sign in SUCCESS!", cred.user.uid);
    } catch (e) {
        console.log("Sign in failed:", e.code, e.message);
        
        console.log(`Trying to create ${email}...`);
        try {
            const cred2 = await createUserWithEmailAndPassword(auth, email, password);
            console.log("Create SUCCESS!", cred2.user.uid);
        } catch (e2) {
            console.log("Create failed:", e2.code, e2.message);
        }
    }
}

test().then(() => process.exit(0));
