// UTK RENDER https://github.com/utkuali/utk_render

import { CfxTexture, LinearFilter, Mesh, NearestFilter, OrthographicCamera, PlaneBufferGeometry, RGBAFormat, Scene, ShaderMaterial, UnsignedByteType, WebGLRenderTarget, WebGLRenderer } from "/module/Three.js";

var isAnimated = false;
var MainRender;

// from https://stackoverflow.com/a/12300351
function dataURItoBlob(dataURI) {
    const byteString = atob(dataURI.split(',')[1]);
    const mimeString = dataURI.split(',')[0].split(':')[1].split(';')[0]

    const ab = new ArrayBuffer(byteString.length);
    const ia = new Uint8Array(ab);

    for (let i = 0; i < byteString.length; i++) {
        ia[i] = byteString.charCodeAt(i);
    }

    const blob = new Blob([ab], { type: mimeString });
    return blob;
}

const normalModeAspectRatio = 1.6;

// citizenfx/screenshot-basic
class GameRender {
    constructor() {
        window.addEventListener('resize', this.resize);
        this.width = window.innerWidth;
        this.height = window.innerHeight;
        this.landscape = false;
        $('#camera-canvas').css({
            width: '100%',
            transform: 'rotate(0deg)'
        });

        this.resizedWidth = this.width / normalModeAspectRatio;
        this.resizedHeight = this.height;

        const cameraRTT = new OrthographicCamera(this.width / -2, this.width / 2, this.height / 2, this.height / -2, -10000, 10000);
        cameraRTT.position.z = 100;
        cameraRTT.setViewOffset(this.width, this.height, 0, 0, this.width, this.height);

        const sceneRTT = new Scene();

        const rtTexture = new WebGLRenderTarget(this.width, this.height, { minFilter: LinearFilter, magFilter: NearestFilter, format: RGBAFormat, type: UnsignedByteType });
        const gameTexture = new CfxTexture();
        gameTexture.needsUpdate = true;

        const material = new ShaderMaterial({
            uniforms: { "tDiffuse": { value: gameTexture } },
            vertexShader: `
			varying vec2 vUv;

			void main() {
				vUv = vec2(uv.x, 1.0-uv.y);
				gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
			}
`,
            fragmentShader: `
			varying vec2 vUv;
			uniform sampler2D tDiffuse;

			void main() {
				gl_FragColor = texture2D(tDiffuse, vUv);
			}
`
        });

        this.material = material;

        const plane = new PlaneBufferGeometry(this.width, this.height);
        const quad = new Mesh(plane, material);
        quad.position.z = -100;
        sceneRTT.add(quad);

        const renderer = new WebGLRenderer();
        renderer.setSize(this.width, this.height);
        renderer.autoClear = false;

        let appendArea = document.createElement("div");
        appendArea.id = "three-game-render";

        document.body.append(appendArea);

        appendArea.appendChild(renderer.domElement);
        appendArea.style.display = 'none';

        this.renderer = renderer;
        this.rtTexture = rtTexture;
        this.sceneRTT = sceneRTT;
        this.cameraRTT = cameraRTT;
        this.gameTexture = gameTexture;

        this.animate = this.animate.bind(this);

        this.animate();
    }

    setLandscape(bool) {
        this.landscape = bool;
        if (bool) {
            this.resizedWidth = this.width;
            this.resizedHeight = this.height;
            $('#camera-canvas').css({
                width: '155%',
                transform: 'rotate(90deg)'
            });
            Rotate(true)
        } else {
            this.resizedWidth = this.width / normalModeAspectRatio;
            this.resizedHeight = this.height;
            $('#camera-canvas').css({
                width: '100%',
                transform: 'rotate(0deg)'

            });
            Rotate(false)
        }
        this.resize()
    }

    getLandscape() {
        return this.landscape;
    }

    resize(screenshot) {
        const cameraRTT = new OrthographicCamera(this.width / -2, this.width / 2, this.height / 2, this.height / -2, -10000, 10000);
        if (screenshot === true) {
            // cameraRTT.setViewOffset(this.width, this.height, 0, 0, this.width, this.height);
        } else {
            // const width = Math.floor(this.height / 2);
            // const width = Math.floor(this.height * 10 / 23);
            // cameraRTT.setViewOffset(this.width, this.height, 0, 0, this.width, this.height);
            const portrait = this.width === this.resizedWidth
            const width = portrait ? this.resizedWidth : this.resizedWidth / 3.5;
            // cameraRTT.setViewOffset(this.width, this.height, width, 0, this.resizedWidth, this.height);
            if (this.canvas) this.canvas.width = this.resizedWidth;

            // cameraRTT.setViewOffset(this.width, this.height, this.width, 0, width, this.height);
        }

        this.cameraRTT = cameraRTT;

        const sceneRTT = new Scene();

        const plane = new PlaneBufferGeometry(this.width, this.height);
        const quad = new Mesh(plane, this.material);
        quad.position.z = -100;
        sceneRTT.add(quad);

        this.sceneRTT = sceneRTT;

        this.rtTexture = new WebGLRenderTarget(this.width, this.height, { minFilter: LinearFilter, magFilter: NearestFilter, format: RGBAFormat, type: UnsignedByteType });

        this?.renderer?.setSize?.(this.width, this.height);
    }

    animate() {
        if (isAnimated) {
            this.renderer.clear();
            this.renderer.render(this.sceneRTT, this.cameraRTT, this.rtTexture, true);

            const width = this.width;
            const height = this.height;

            if (this.canvas.width !== this.resizedWidth || this.canvas.height !== height) {
                this.canvas.width = this.resizedWidth;
                this.canvas.height = height;
            }

            const read = new Uint8Array(width * height * 4);
            this.renderer.readRenderTargetPixels(this.rtTexture, 0, 0, width, height, read);

            const cxt = this.canvas.getContext('2d');
            const imageData = new ImageData(new Uint8ClampedArray(read.buffer), width, height);
            cxt.putImageData(imageData, 0, 0);
            requestAnimationFrame(this.animate);
        }
    }

    createTempCanvas() {
        this.canvas = document.createElement("canvas");
        this.canvas.style.display = 'inline';
        this.canvas.width = this.width;
        this.canvas.height = this.height;
    }

    renderToTarget(element) {
        this.resize(false);
        this.canvas = element;
        isAnimated = true;
        this.animate()
    }

    requestScreenshot = (url, field) => new Promise(res => {
        if (!url || !field) return console.error('url or field is not defined');
        isAnimated = true;
        const imageURL = this.canvas.toDataURL("image/png", 1.0);

        const formData = new FormData();
        formData.append(field, dataURItoBlob(imageURL), `screenshot.png`);

        fetch(url, {
            method: 'POST',
            mode: 'cors',
            body: formData
        })
            .then(response => response.text())
            .then(text => {
                text = JSON.parse(text);
                if (!text.attachments) return res(text.data.url);
                res(text.attachments[0].proxy_url)
            })
            .catch(err => {
                console.error(err);
                res(false);
            });
    })

    stop() {
        isAnimated = false;
        if (this.canvas) {
            if (this.canvas.style.display != "none") {
                this.canvas.style.display = "none";
            }
        }
        this.resize(true);
        this.resizedWidth = this.width;
        this.resizedHeight = this.height;
        this.setLandscape(false);
    }
}

setTimeout(() => {
    MainRender = new GameRender();
    window.MainRender = MainRender;
}, 1000);
