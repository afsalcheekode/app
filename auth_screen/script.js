document.addEventListener('DOMContentLoaded', () => {
    const inputs = document.querySelectorAll('.code-inputs input');
    const continueBtn = document.getElementById('continue-btn');

    // Handle input behavior
    inputs.forEach((input, index) => {
        // Auto-focus next input
        input.addEventListener('input', (e) => {
            if (e.inputType === 'deleteContentBackward') return;
            
            if (input.value.length === 1 && index < inputs.length - 1) {
                inputs[index + 1].focus();
            }
            
            checkCompletion();
        });

        // Handle backspace
        input.addEventListener('keydown', (e) => {
            if (e.key === 'Backspace' && input.value.length === 0 && index > 0) {
                inputs[index - 1].focus();
            }
        });

        // Paste support
        input.addEventListener('paste', (e) => {
            e.preventDefault();
            const data = e.clipboardData.getData('text').trim().replace(/[^a-zA-Z0-9]/g, '');
            const chars = data.split('');
            
            chars.forEach((char, i) => {
                if (index + i < inputs.length) {
                    inputs[index + i].value = char.toUpperCase();
                }
            });
            
            const nextIndex = Math.min(index + chars.length, inputs.length - 1);
            inputs[nextIndex].focus();
            
            checkCompletion();
        });
    });

    function checkCompletion() {
        const allFilled = Array.from(inputs).every(input => input.value.length === 1);
        continueBtn.disabled = !allFilled;
    }

    // Initial check
    checkCompletion();

    continueBtn.addEventListener('click', () => {
        const code = Array.from(inputs).map(input => input.value).join('');
        alert(`Authorizing with code: ${code}`);
    });
});
