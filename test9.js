const { initializeApp } = require('firebase/app');
const { getFirestore, collection, query, where, getDocs } = require('firebase/firestore');

const firebaseConfig = {
    apiKey: 'AIzaSyDtzmMvUktdEvlK-_6_vB_k3O6paWlznWQ',
    appId: '1:313350964672:web:0a5ba8a1d990c433cef425',
    projectId: 'studio-6116270073-a85c2',
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function test() {
    console.log("Checking if user doc exists in 'users' collection for zayanhz02...");
    const q = query(collection(db, 'users'), where('username', '==', 'zayanhz02'));
    const querySnapshot = await getDocs(q);
    if (querySnapshot.empty) {
        console.log("No user docs found for zayanhz02.");
    } else {
        querySnapshot.forEach((doc) => {
            console.log("Found user doc:", doc.id, doc.data());
        });
    }
}

test().then(() => process.exit(0));
