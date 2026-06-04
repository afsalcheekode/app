const { initializeApp } = require('firebase/app');
const { getAuth, signInWithEmailAndPassword, createUserWithEmailAndPassword } = require('firebase/auth');

const firebaseConfig = {
    apiKey: 'AIzaSyDtzmMvUktdEvlK-_6_vB_k3O6paWlznWQ',
    appId: '1:313350964672:web:0a5ba8a1d990c433cef425',
    projectId: 'studio-6116270073-a85c2',
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);

async function test() {
    try {
        console.log("Trying to sign in zayanhz02@v2.harakat.com...");
        await signInWithEmailAndPassword(auth, 'zayanhz02@v2.harakat.com', 'hz0201');
        console.log("Sign in successful!");
    } catch (e) {
        console.log("Sign in failed:", e.code, e.message);
        if (e.code === 'auth/user-not-found' || e.code === 'auth/invalid-credential') {
            try {
                console.log("Auto-creating zayanhz02@v2.harakat.com...");
                await createUserWithEmailAndPassword(auth, 'zayanhz02@v2.harakat.com', 'hz0201');
                console.log("Create successful!");
            } catch (createErr) {
                console.error("Create failed:", createErr.code, createErr.message);
            }
        }
    }
}
test().then(() => process.exit(0));
