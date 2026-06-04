const { initializeApp } = require('firebase/app');
const { getAuth, signInWithEmailAndPassword, deleteUser } = require('firebase/auth');

const firebaseConfig = {
    apiKey: 'AIzaSyDtzmMvUktdEvlK-_6_vB_k3O6paWlznWQ',
    appId: '1:313350964672:web:0a5ba8a1d990c433cef425',
    projectId: 'studio-6116270073-a85c2',
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);

async function test() {
    try {
        console.log("Signing in to delete...");
        const result = await signInWithEmailAndPassword(auth, 'zayanhz02@v2.harakat.com', 'hz0201');
        await deleteUser(result.user);
        console.log("User deleted successfully!");
    } catch (e) {
        console.error("Failed:", e);
    }
}
test().then(() => process.exit(0));
