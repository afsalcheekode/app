const { initializeApp } = require('firebase/app');
const { getAuth, createUserWithEmailAndPassword } = require('firebase/auth');

const firebaseConfig = {
    apiKey: 'AIzaSyDtzmMvUktdEvlK-_6_vB_k3O6paWlznWQ',
    appId: '1:313350964672:web:0a5ba8a1d990c433cef425',
    projectId: 'studio-6116270073-a85c2',
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);

async function run() {
    try {
        const cred = await createUserWithEmailAndPassword(auth, 'zayanhz02@harakat.com', 'hz0201');
        console.log("SUCCESS CREATING!", cred.user.uid);
    } catch (e) {
        console.log("FAILED creating:", e.code, e.message);
    }
}

run().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
