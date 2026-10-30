import { useDispatch, useSelector } from 'react-redux';
import './HomeBar.css';
import { closeApp } from '../../store/slices/phoneSlice';
import { isLightApp } from '../../np/theme';
import { playSound } from '../../np/sound';

export default function HomeBar() {
    const dispatch = useDispatch();
    const activeApp = useSelector((s) => s.phone.activeApp);
    const tone = useSelector((s) => s.phone.statusTone);
    const dark = activeApp && (tone ? tone === 'dark' : isLightApp(activeApp));

    const handleHome = () => {
        if (!activeApp) return;
        playSound('home');
        dispatch(closeApp());
    };

    return (
        <div className={`homebar${dark ? ' homebar--light' : ''}`}>
            <div className="homebar__pill" onClick={handleHome} />
        </div>
    );
}
