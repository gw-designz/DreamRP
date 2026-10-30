<template>
    <div class="texture">
        <Transition name="slide">
            <Page :key="currentPage" :page="pages[currentPage]" :empty="currentPage === -1"></Page>
        </Transition>
    </div>
</template>

<script>
import { mapState } from 'vuex';
import Page from "@/components/Page.vue";

export default {
    name: 'App',
    components: {Page},
    data() {
        return {
        }
    },
    computed: {
        ...mapState('os', ['currentPage', 'pages'])
    },
    methods: {
    },
    mounted() {
        if(!this.$store.state.isDev) {
            fetch(`https://prp-scanner/scanner:duiLoaded`, {method: "POST", body: JSON.stringify({}), headers: {"Content-Type": "application/json"}});
        }
    },
    beforeUnmount() {
    }
}
</script>

<style lang="scss">
@import "main";

.slide-enter-active,
.slide-leave-active {
    transition: all 0.2s ease;
}

.slide-enter-from {
    transform: translateX(-100%);
}

.slide-leave-to {
    transform: translateX(100%);
}
</style>