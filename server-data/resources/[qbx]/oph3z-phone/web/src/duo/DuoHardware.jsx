import './duo.css';

// Physical parts of the iPhone Duo drawn around the screen: side buttons and the hinge caps
// that show on the top and bottom edges once the phone is unfolded.
export default function DuoHardware() {
    return (
        <div className="duo-hw" aria-hidden>
            <span className="duo-hw__btn duo-hw__btn--action" />
            <span className="duo-hw__btn duo-hw__btn--volup" />
            <span className="duo-hw__btn duo-hw__btn--voldown" />
            <span className="duo-hw__btn duo-hw__btn--power" />
            <span className="duo-hw__btn duo-hw__btn--capture" />
            <span className="duo-hw__hinge duo-hw__hinge--top" />
            <span className="duo-hw__hinge duo-hw__hinge--bottom" />
        </div>
    );
}
