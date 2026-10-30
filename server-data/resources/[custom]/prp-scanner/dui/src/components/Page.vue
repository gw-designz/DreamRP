<template>
    <div class="page" v-if="!empty">
        <div class="row-top">
            <div class="col">
                <p class="title" :style="`--color: ${page.titleColor}`">{{page.title}}</p>
                <p class="subtitle">{{page.subTitle}}</p>
            </div>

            <div class="icon" v-if="page.icon" :style="`--color: ${page.iconColor};`">
                <img :src="`img/${page.icon}.svg`" alt="icon">
                <div class="count" v-if="page.iconNumber != null">
                    {{ page.iconNumber }}
                </div>
            </div>
        </div>

        <div class="menu-items">
            <div class="menu-item" v-for="item in page.menuItems" :style="`--color: ${item.color}; --fontColor: ${item.fontColor};`" :class="{halfSize: item.halfSize}">
                <div class="image">
                    <img :src="`img/${item.icon}.svg`">
                </div>

                {{ item.title }}
            </div>
        </div>

        <div class="bottom-text" v-if="page.bottomText" :style="`--color: ${page.bottomTextColor}`">
            {{page.bottomText}}
        </div>
    </div>
    <div class="page" v-else>
        <div class="row-top" style="margin: auto">
            <div class="col">
                <p class="title" :style="`--color: #00FF42;`">MTQ_BA2115</p>
                <p class="subtitle">__NODETECTED</p>
            </div>
        </div>
    </div>
</template>

<script>

export default {
    name: "Page",
    props: {
        page: Object,
        empty: Boolean,
    },
}
</script>

<style scoped lang="scss">
.page {
    position: absolute;
    left: calc(50% - 180.5px); // 361px / 2
    padding: 2rem 1.5rem;
    font-weight: 700;
    width: 361px;
    height: 100%;
    //outline: 1px dashed red;

    display: flex;
    flex-direction: column;

    .row-top {
        display: flex;
        justify-content: space-between;
        align-items: center;

        .col {
            display: flex;
            flex-direction: column;
            justify-content: center;
            gap: 1rem;

            .title {
                background: var(--color);
                padding: 0 .5rem;
                color: #04080D;
                font-size: 1.5rem;
            }
        }

        .icon {
            position: relative;
            display: flex;
            justify-content: center;
            align-items: center;
            width: 4.3125rem;
            height: 4.3125rem;
            background: var(--color);

            img {
                width: 3rem;
                height: 3rem;
            }

            .count {
                position: absolute;
                bottom: 0;
                right: 0;
                background: #04080D;
                border: 3px solid var(--color);
                color: var(--color);
                line-height: 100%;
                display: flex;
                justify-content: center;
                align-items: center;
                width: 2rem;
                height: 2rem;
                translate: 0 50%;
            }
        }
    }

    .menu-items {
        margin: auto 0;
        display: grid;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        grid-gap: 1.5rem 1rem;
        color: black;
        height: fit-content;

        .menu-item {
            display: flex;
            align-items: center;
            gap: 1.5rem;
            background: var(--color);
            padding: .75rem 1.5rem;
            grid-column: span 2;
            height: fit-content;


            color: var(--fontColor, #000);
            font-size: 1.5rem;
            font-weight: 700;

            &.halfSize {
                grid-column: span 1;
                padding: .75rem;
                font-size: 0.875rem;
                gap: .75rem;

                .image {
                    width: 2rem;
                    height: 2rem;
                }
            }

            .image {
                width: 3rem;
                height: 3rem;

                img {
                    width: inherit;
                    height: inherit;
                }
            }
        }
    }

    .bottom-text {
        padding: 0.75rem 1.5rem;
        background: var(--color);
        color: black;
        text-align: center;
    }
}
</style>